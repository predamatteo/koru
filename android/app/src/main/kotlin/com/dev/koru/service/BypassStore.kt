package com.dev.koru.service

import android.content.Context
import android.util.Log
import com.dev.koru.overlay.BlockReason
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject

/**
 * Persistenza CROSS-PROCESS dei bypass attivi ("Open anyway" + durata).
 *
 * Koru gira l'enforcement in due processi: [KoruAccessibilityService] in
 * `:accessibility` (primario, event-driven) e [LockForegroundService] /
 * [LockRunnable] nel main (backup polling). Prima i bypass vivevano in una
 * `ConcurrentHashMap` dentro il companion di [OverlayManager] → **una copia
 * per processo**: un bypass concesso in `:accessibility` era invisibile al
 * backup, e viceversa. Quando l'AccessibilityService veniva ucciso dall'OEM
 * mentre un "+5 min" era attivo, il backup non lo vedeva e ri-bloccava
 * l'utente (fail-closed, ma UX rotta); e gli auto-revoke non si
 * coordinavano. Questo store mette la fonte di verità su disco, condivisa.
 *
 * File: `filesDir/koru_bypasses.json`. Schema:
 * ```
 * {
 *   "com.pkg":            {"until": 1716700000000, "reason": "USAGE_LIMIT"},
 *   "com.pkg|reddit.com": {"until": 1716700000000, "reason": "WEBSITE_BLOCKED"}
 * }
 * ```
 * La chiave è `package` (bypass app-wide) o `package|dominio` (bypass del
 * solo sito) — vedi `OverlayManager.bypassKey`.
 *
 * Cache: `AtomicReference<CachedSnapshot>` invalidata via `file.lastModified()`
 * — STESSO pattern di [AppUsageLimitsStore], NON quello di [BypassCountStore]
 * (la cui cache è permanente). La coerenza cross-process qui è obbligatoria:
 * la prima read di un processo dopo una write dell'altro deve vedere il dato
 * fresco, e il check su lastModified lo garantisce.
 *
 * Concorrenza: le mutazioni ([put]/[removePackage]/[clearAll]) sono
 * `synchronized` per rendere atomico il read-modify-write INTRA-processo (più
 * thread: binder di accessibility, polling thread, main UI). CROSS-processo le
 * write restano best-effort: i due processi non scrivono mai davvero in
 * contemporanea (il backup si disattiva finché l'AccessibilityService è vivo,
 * vedi `LockRunnable`), e nella micro-finestra di handoff l'esito peggiore è
 * un bypass perso → si ri-blocca (fail-closed, sicuro per il self-control).
 */
object BypassStore {
    private const val TAG = "BypassStore"
    private const val FILE_NAME = "koru_bypasses.json"

    private data class CachedSnapshot(
        val data: Map<String, BypassEntry>,
        val fileLastModified: Long,
    )

    private val cache = AtomicReference<CachedSnapshot?>(null)
    private val writeLock = Any()

    /// Mappa corrente chiave→bypass (incluse eventuali entry già scadute: i
    /// chiamati [OverlayManager] filtrano per `until` al momento della query).
    fun read(context: Context): Map<String, BypassEntry> {
        val file = File(context.filesDir, FILE_NAME)
        val lastModified = if (file.exists()) file.lastModified() else 0L
        val current = cache.get()
        if (current != null && current.fileLastModified == lastModified) {
            return current.data
        }
        return try {
            if (!file.exists()) {
                val empty = emptyMap<String, BypassEntry>()
                cache.set(CachedSnapshot(empty, 0L))
                return empty
            }
            val json = JSONObject(file.readText())
            val out = mutableMapOf<String, BypassEntry>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val obj = json.optJSONObject(k) ?: continue
                val until = obj.optLong("until", 0L)
                if (until <= 0L) continue
                out[k] = BypassEntry(until, parseReason(obj.optString("reason")))
            }
            val frozen = out.toMap()
            cache.set(CachedSnapshot(frozen, lastModified))
            frozen
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read bypasses, returning empty", e)
            emptyMap()
        }
    }

    /// Inserisce/aggiorna il bypass per [key], eliminando al volo le entry già
    /// scadute così il file non cresce indefinitamente.
    fun put(context: Context, key: String, entry: BypassEntry) = synchronized(writeLock) {
        val now = System.currentTimeMillis()
        val updated = read(context).filterValues { it.until > now }.toMutableMap()
        updated[key] = entry
        write(context, updated)
    }

    /// Rimuove il bypass app-wide (`packageName`) e TUTTE le varianti
    /// per-dominio (`packageName|*`). Simmetrico a `OverlayManager.clearBypass`.
    fun removePackage(context: Context, packageName: String) = synchronized(writeLock) {
        val prefix = "$packageName|"
        val updated = read(context).filterKeys { it != packageName && !it.startsWith(prefix) }
        // Evita una write se non è cambiato nulla (no-op frequente nell'auto-revoke).
        if (updated.size != read(context).size) write(context, updated)
    }

    fun clearAll(context: Context) = synchronized(writeLock) {
        write(context, emptyMap())
    }

    private fun write(context: Context, map: Map<String, BypassEntry>) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val json = JSONObject()
            for ((k, v) in map) {
                json.put(
                    k,
                    JSONObject().apply {
                        put("until", v.until)
                        put("reason", v.reason.name)
                    },
                )
            }
            file.writeText(json.toString())
            cache.set(CachedSnapshot(map.toMap(), file.lastModified()))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write bypasses", e)
        }
    }

    /// `reason` sconosciuto (downgrade app / file corrotto) ⇒ APP_BLOCKED:
    /// è il default FAIL-SAFE per il cap (un profilo-bypass non sospende il
    /// limite), vedi `OverlayManager.isLimitBypassActive`.
    private fun parseReason(name: String?): BlockReason =
        try {
            if (name.isNullOrEmpty()) BlockReason.APP_BLOCKED else BlockReason.valueOf(name)
        } catch (_: IllegalArgumentException) {
            BlockReason.APP_BLOCKED
        }
}
