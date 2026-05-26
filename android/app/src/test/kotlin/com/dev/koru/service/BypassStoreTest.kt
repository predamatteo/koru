package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.dev.koru.overlay.BlockReason
import com.google.common.truth.Truth.assertThat
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests per [BypassStore] — la persistenza cross-process introdotta dal fix M2.
 *
 * Coprono round-trip della serializzazione, il fail-safe di parsing del
 * `reason`, lo skip delle entry con `until<=0`, e soprattutto la proprietà
 * CENTRALE di M2: un bypass scritto da un processo è rileggibile da un altro.
 * "L'altro processo" è simulato azzerando la cache statica, così la `read`
 * successiva ricarica da disco come farebbe un processo con cache vuota.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class BypassStoreTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()
    private val pkg = "com.instagram.android"
    private val fileName = "koru_bypasses.json"

    @Before
    fun setUp() {
        resetState()
    }

    @After
    fun tearDown() {
        resetState()
    }

    @Test
    fun put_isReadableByOtherProcess() {
        val until = System.currentTimeMillis() + 5 * 60_000L
        BypassStore.put(ctx, pkg, BypassEntry(until, BlockReason.USAGE_LIMIT))
        simulateOtherProcess()
        val entry = BypassStore.read(ctx)[pkg]
        assertThat(entry).isNotNull()
        assertThat(entry!!.until).isEqualTo(until)
        assertThat(entry.reason).isEqualTo(BlockReason.USAGE_LIMIT)
    }

    @Test
    fun reason_roundTripsForEveryValue() {
        val until = System.currentTimeMillis() + 60_000L
        for (reason in BlockReason.values()) {
            BypassStore.put(ctx, pkg, BypassEntry(until, reason))
            simulateOtherProcess()
            assertThat(BypassStore.read(ctx)[pkg]?.reason).isEqualTo(reason)
        }
    }

    @Test
    fun unknownReason_parsesToAppBlocked_failSafe() {
        // File forgiato/corrotto con reason sconosciuto ⇒ APP_BLOCKED (NON
        // USAGE_LIMIT), così non sospende il cap giornaliero.
        val until = System.currentTimeMillis() + 60_000L
        writeRawFile("""{"$pkg":{"until":$until,"reason":"GARBAGE_REASON"}}""")
        assertThat(BypassStore.read(ctx)[pkg]?.reason).isEqualTo(BlockReason.APP_BLOCKED)
    }

    @Test
    fun missingReason_parsesToAppBlocked_failSafe() {
        val until = System.currentTimeMillis() + 60_000L
        writeRawFile("""{"$pkg":{"until":$until}}""")
        assertThat(BypassStore.read(ctx)[pkg]?.reason).isEqualTo(BlockReason.APP_BLOCKED)
    }

    @Test
    fun nonPositiveUntil_isSkippedOnRead() {
        writeRawFile(
            """{"$pkg":{"until":0,"reason":"USAGE_LIMIT"},""" +
                """"other.pkg":{"until":-5,"reason":"USAGE_LIMIT"}}""",
        )
        assertThat(BypassStore.read(ctx)).isEmpty()
    }

    @Test
    fun removePackage_clearsAppWideAndPerDomain_visibleCrossProcess() {
        val until = System.currentTimeMillis() + 60_000L
        BypassStore.put(ctx, pkg, BypassEntry(until, BlockReason.APP_BLOCKED))
        BypassStore.put(ctx, "$pkg|reddit.com", BypassEntry(until, BlockReason.WEBSITE_BLOCKED))
        BypassStore.put(ctx, "other.pkg", BypassEntry(until, BlockReason.APP_BLOCKED))
        BypassStore.removePackage(ctx, pkg)
        simulateOtherProcess()
        val map = BypassStore.read(ctx)
        // Rimosse la app-wide e la per-dominio di pkg; l'altra app resta.
        assertThat(map.keys).containsExactly("other.pkg")
    }

    @Test
    fun put_prunesOtherExpiredEntries() {
        // Una entry passata (until>0 ma < now) resta su disco finché un put non
        // la pota: verifichiamo che il prossimo put la elimini.
        val expired = System.currentTimeMillis() - 1_000L
        writeRawFile("""{"stale.pkg":{"until":$expired,"reason":"USAGE_LIMIT"}}""")
        val valid = System.currentTimeMillis() + 60_000L
        BypassStore.put(ctx, pkg, BypassEntry(valid, BlockReason.USAGE_LIMIT))
        simulateOtherProcess()
        assertThat(BypassStore.read(ctx).keys).containsExactly(pkg)
    }

    @Test
    fun clearAll_emptiesStore_visibleCrossProcess() {
        val until = System.currentTimeMillis() + 60_000L
        BypassStore.put(ctx, pkg, BypassEntry(until, BlockReason.USAGE_LIMIT))
        BypassStore.clearAll(ctx)
        simulateOtherProcess()
        assertThat(BypassStore.read(ctx)).isEmpty()
    }

    // -------- helpers --------

    private fun resetState() {
        File(ctx.filesDir, fileName).delete()
        cacheField().set(null)
    }

    /// Azzera la cache statica → la prossima read ricarica da disco, come un
    /// secondo processo che non ha ancora popolato la propria cache.
    private fun simulateOtherProcess() {
        cacheField().set(null)
    }

    /// Scrive un file grezzo (per simulare contenuti forgiati/corrotti) e
    /// invalida la cache così la read successiva ricarica da disco.
    private fun writeRawFile(content: String) {
        File(ctx.filesDir, fileName).writeText(content)
        cacheField().set(null)
    }

    private fun cacheField(): AtomicReference<Any?> {
        val f = BypassStore::class.java.getDeclaredField("cache")
        f.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        return f.get(BypassStore) as AtomicReference<Any?>
    }
}
