package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * ARCH-03 — test dell'astrazione condivisa [FileBackedStore], modellata sul
 * gold standard [BypassStore]. Verifica le 4 garanzie richieste dalla review:
 *  1. scrittura ATOMICA (temp+rename) e round-trip,
 *  2. invalidazione cache su `(mtime,length)` — copre il bug CR-04 (cache che
 *     non si invalidava mai),
 *  3. round-trip "scritto da un processo, letto da un altro" (cache azzerata =
 *     re-load da disco) tramite [FileBackedStore.mutate] sotto lock,
 *  4. fail-safe su file corrotto via `corruptFallback`, incluso il fallback
 *     "tieni l'ultimo valore in cache" usato da [AppUsageLimitsStore] (SEC-09).
 *
 * Usa un codec concreto `Map<String,Int>` ↔ JSON per esercitare l'astrazione in
 * isolamento dagli store reali.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class FileBackedStoreTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()
    private val fileName = "fbs_test.json"

    /// Fallback configurabile per i test: di default mappa vuota, ma alcuni test
    /// lo cambiano a "tieni l'ultimo noto" per esercitare SEC-09.
    private var fallback: (Map<String, Int>?) -> Map<String, Int> = { emptyMap() }

    private fun newStore(): FileBackedStore<Map<String, Int>> = FileBackedStore(
        fileName = fileName,
        codec = object : FileBackedStore.Codec<Map<String, Int>> {
            override fun serialize(value: Map<String, Int>): String {
                val json = JSONObject()
                for ((k, v) in value) json.put(k, v)
                return json.toString()
            }

            override fun deserialize(raw: String): Map<String, Int> {
                val json = JSONObject(raw)
                val out = mutableMapOf<String, Int>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    out[k] = json.getInt(k)
                }
                return out
            }
        },
        corruptFallback = { lastCached -> fallback(lastCached) },
    )

    @Before
    fun setUp() = cleanup()

    @After
    fun tearDown() = cleanup()

    private fun cleanup() {
        File(ctx.filesDir, fileName).delete()
        File(ctx.filesDir, "$fileName.tmp").delete()
        File(ctx.filesDir, "$fileName.lock").delete()
        fallback = { emptyMap() }
    }

    // -------- 1. write atomica + round-trip --------

    @Test
    fun write_thenRead_roundtrip() {
        val store = newStore()
        assertThat(store.write(ctx, mapOf("a" to 1, "b" to 2))).isTrue()
        assertThat(store.read(ctx)).containsExactly("a", 1, "b", 2)
    }

    @Test
    fun write_isAtomic_noTempLeftBehind() {
        val store = newStore()
        store.write(ctx, mapOf("a" to 1))
        // Dopo una write riuscita il file finale esiste e il temp è stato
        // rinominato (non resta un .tmp orfano).
        assertThat(File(ctx.filesDir, fileName).exists()).isTrue()
        assertThat(File(ctx.filesDir, "$fileName.tmp").exists()).isFalse()
    }

    @Test
    fun read_missingFile_returnsFreshFallback() {
        // File assente ⇒ corruptFallback(null) ⇒ mappa vuota (default).
        assertThat(newStore().read(ctx)).isEmpty()
    }

    // -------- 2. invalidazione cache su (mtime,length) (CR-04) --------

    @Test
    fun read_afterExternalWrite_reloadsViaLengthChange() {
        val store = newStore()
        store.write(ctx, mapOf("a" to 1))
        assertThat(store.read(ctx)).containsExactly("a", 1)

        // Un "altro processo" sovrascrive il file direttamente (cambia la
        // length). La read successiva deve rilevarlo e ricaricare — NON
        // ritornare la cache stale (era il cuore di CR-04).
        File(ctx.filesDir, fileName).writeText("""{"a":1,"b":2,"c":3}""")
        assertThat(store.read(ctx)).containsExactly("a", 1, "b", 2, "c", 3)
    }

    @Test
    fun read_cacheHit_returnsSameInstance_noReparse() {
        val store = newStore()
        store.write(ctx, mapOf("a" to 1))
        val first = store.read(ctx)
        val second = store.read(ctx)
        // Stesso (mtime,length) ⇒ cache hit ⇒ identica istanza (nessun re-parse).
        assertThat(second).isSameInstanceAs(first)
    }

    // -------- 3. round-trip cross-process via mutate (lock RMW) --------

    @Test
    fun mutate_visibleAfterCacheCleared_simulatingOtherProcess() {
        val store = newStore()
        store.mutate(ctx) { it + ("a" to 1) }
        store.mutate(ctx) { it + ("b" to 2) }
        // Secondo processo: cache vuota ⇒ legge da disco.
        store.invalidateCacheForTest()
        assertThat(store.read(ctx)).containsExactly("a", 1, "b", 2)
    }

    @Test
    fun mutate_readsFreshFromDisk_notStaleCache() {
        val store = newStore()
        store.write(ctx, mapOf("a" to 1))
        // Un altro processo scrive direttamente sul disco DOPO che la cache di
        // questo store è popolata.
        File(ctx.filesDir, fileName).writeText("""{"a":1,"x":9}""")
        // mutate legge FRESCO da disco (readFresh), quindi vede "x":9 e lo
        // preserva mentre aggiunge "y".
        store.mutate(ctx) { it + ("y" to 7) }
        store.invalidateCacheForTest()
        assertThat(store.read(ctx)).containsExactly("a", 1, "x", 9, "y", 7)
    }

    @Test
    fun mutate_noChange_isNoOp_returnsTrue() {
        val store = newStore()
        store.write(ctx, mapOf("a" to 1))
        val before = File(ctx.filesDir, fileName).lastModified()
        // Transform che ritorna lo stesso valore ⇒ niente write.
        val ok = store.mutate(ctx) { it }
        assertThat(ok).isTrue()
        assertThat(File(ctx.filesDir, fileName).lastModified()).isEqualTo(before)
    }

    @Test
    fun write_populatesCache_immediately() {
        val store = newStore()
        store.write(ctx, mapOf("a" to 1))
        // La write popola la cache senza un read intermedio.
        assertThat(store.cachedDataForTest()).containsExactly("a", 1)
    }

    // -------- 4. fail-safe su file corrotto --------

    @Test
    fun read_corruptFile_default_returnsEmptyFallback() {
        File(ctx.filesDir, fileName).writeText("{not json")
        assertThat(newStore().read(ctx)).isEmpty()
    }

    @Test
    fun read_corruptFile_keepLastKnown_returnsCachedValue() {
        // SEC-09: fallback "tieni l'ultimo noto". Prima carichiamo uno stato
        // valido (popola la cache), poi corrompiamo il file: la read deve
        // restituire l'ultimo valore noto, NON svuotare.
        fallback = { lastCached -> lastCached ?: emptyMap() }
        val store = newStore()
        store.write(ctx, mapOf("cap" to 30))
        assertThat(store.read(ctx)).containsExactly("cap", 30)

        // File torn (lunghezza diversa così il check (mtime,length) forza reload).
        File(ctx.filesDir, fileName).writeText("{tor")
        assertThat(store.read(ctx)).containsExactly("cap", 30)
    }

    @Test
    fun read_corruptFile_keepLastKnown_noCache_returnsEmpty() {
        // Stesso fallback, ma senza cache (primo avvio col file già corrotto):
        // non c'è uno stato precedente → mappa vuota.
        fallback = { lastCached -> lastCached ?: emptyMap() }
        File(ctx.filesDir, fileName).writeText("{tor")
        assertThat(newStore().read(ctx)).isEmpty()
    }
}
