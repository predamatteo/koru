package com.dev.koru.service

import android.content.Context
import org.json.JSONObject

/**
 * Lasciapassare **monouso e a scadenza** per l'"Open anyway" di un blocco
 * USAGE_LIMIT su un'app con `challengeLock` attivo.
 *
 * ## Perché serve un file
 *
 * La sfida di sblocco è un puzzle di GLIFI, e i glifi vivono solo in Dart: il
 * Kotlin ragiona su indici di caselle e non sa disegnare un'icona (vedi la
 * nota "Kotlin non sa nulla di glifi" in CLAUDE.md). L'overlay però è Compose
 * nativo. L'unico modo di gateare il bypass senza duplicare la tabella dei
 * glifi nei due runtime è quindi: l'overlay manda l'utente in Koru, Dart fa il
 * puzzle e, se lo supera, deposita QUI un lasciapassare che l'overlay legge.
 *
 * ## Proprietà che lo rendono un gate e non una formalità
 *
 * - **Legato al package.** Superare la sfida per Instagram non apre YouTube.
 * - **A scadenza breve** ([TTL_MS]): un lasciapassare dimenticato non diventa
 *   un permesso permanente scoperto tre ore dopo.
 * - **Monouso.** [consume] lo rimuove quando il bypass viene davvero concesso;
 *   il secondo "Open anyway" ricomincia dal puzzle. Senza questo, la prima
 *   sfida della giornata pagherebbe per tutte.
 *
 * Fail-**secure** su file corrotto: nessun lasciapassare (mappa vuota), cioè
 * la sfida va rifatta. È l'opposto di [AppUsageLimitsStore], che su corruzione
 * tiene gli ultimi cap noti — là il fail-safe è "il limite resta", qui è "il
 * permesso non c'è".
 */
object UsageChallengePassStore {
    private const val FILE_NAME = "koru_usage_challenge_pass.json"

    /// Quanto vale un lasciapassare appena emesso. Deve bastare al giro
    /// Koru → app bersaglio (una manciata di secondi), non a una pausa caffè.
    const val TTL_MS = 120_000L

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<Map<String, Long>> {
            override fun serialize(value: Map<String, Long>): String {
                val json = JSONObject()
                for ((k, v) in value) json.put(k, v)
                return json.toString()
            }

            override fun deserialize(raw: String): Map<String, Long> {
                val json = JSONObject(raw)
                val out = mutableMapOf<String, Long>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    val expiry = json.optLong(k, 0L)
                    if (expiry > 0L) out[k] = expiry
                }
                return out.toMap()
            }
        },
        // Fail-secure: file illeggibile ⇒ nessun permesso, la sfida va rifatta.
        corruptFallback = { emptyMap() },
    )

    /// Emette un lasciapassare per [packageName], valido [TTL_MS] da adesso.
    /// Chiamato SOLO dopo che Dart ha verificato la sfida.
    fun grant(context: Context, packageName: String, nowMs: Long = System.currentTimeMillis()): Boolean {
        val next = valid(context, nowMs) + (packageName to nowMs + TTL_MS)
        return store.write(context, next)
    }

    /// `true` se [packageName] ha un lasciapassare ancora valido. Non lo
    /// consuma: l'overlay lo interroga a ogni render.
    fun isValid(
        context: Context,
        packageName: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean = (valid(context, nowMs)[packageName] ?: 0L) > nowMs

    /// Brucia il lasciapassare di [packageName]. Va chiamato quando il bypass
    /// viene CONCESSO: è ciò che rende il gate ripetibile invece di una tantum.
    fun consume(context: Context, packageName: String, nowMs: Long = System.currentTimeMillis()) {
        val current = valid(context, nowMs)
        if (!current.containsKey(packageName)) return
        store.write(context, current - packageName)
    }

    /// Snapshot senza le voci scadute. La potatura avviene in lettura: non c'è
    /// nessun momento naturale in cui girare a fare pulizia, e il file resta
    /// comunque di poche decine di byte.
    private fun valid(context: Context, nowMs: Long): Map<String, Long> =
        store.read(context).filterValues { it > nowMs }

    // ---------------- test hooks ----------------

    internal fun invalidateCacheForTest() = store.invalidateCacheForTest()
}
