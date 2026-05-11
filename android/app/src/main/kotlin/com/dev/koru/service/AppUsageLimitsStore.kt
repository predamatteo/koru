package com.dev.koru.service

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject

/**
 * Persistenza cross-process dei limiti giornalieri per-app. Scritto dal main
 * process via MethodChannel, letto da [KoruAccessibilityService] nel processo
 * `:accessibility`.
 *
 * File: `filesDir/koru_app_limits.json`. Lo schema supporta due formati:
 *
 * - **Legacy** (`{"com.pkg": 30}`): l'integer è il cap in minuti; il flag
 *   `strict` viene assunto `true` (interpretazione conservativa: l'utente
 *   aveva impostato un limite, lo trattiamo come hard cap finché non lo
 *   modifica esplicitamente).
 * - **Esteso** (`{"com.pkg": {"minutes": 30, "strict": true}}`): formato
 *   canonico, scritto da `save()`.
 *
 * `strict=true` ⇒ il blocco USAGE_LIMIT non permette "Open anyway".
 * `strict=false` ⇒ progressive friction (vedi [BypassCountStore]).
 *
 * Hardening (S6):
 * - Cache `AtomicReference<CachedSnapshot>` con baseline `elapsedRealtime`
 *   per evitare il file read ad ogni check del polling (1Hz). Era il bottleneck
 *   identificato dal Mobile Builder: ogni iterazione del polling parsava
 *   l'intero JSON da disco. Ora la prima read mette in cache, le successive
 *   sono O(1). La cache è invalidata su [save] (write esplicita).
 * - Niente sync API: la mutabilità è solo via [save], che bumpea il counter
 *   di versione e tutti i lettori successivi vedono il nuovo valore.
 */
object AppUsageLimitsStore {
    private const val TAG = "AppUsageLimitsStore"
    private const val FILE_NAME = "koru_app_limits.json"

    /// Limit config per un singolo package. `minutes <= 0` significa nessun
    /// limite attivo (lo store filtra questi entries via [save]).
    data class LimitEntry(val minutes: Int, val strict: Boolean)

    private data class CachedSnapshot(
        val data: Map<String, LimitEntry>,
        val baselineElapsedMs: Long,
        val fileLastModified: Long,
    )

    private val cache = AtomicReference<CachedSnapshot?>(null)

    fun read(context: Context): Map<String, LimitEntry> {
        val current = cache.get()
        val file = File(context.filesDir, FILE_NAME)
        val lastModified = if (file.exists()) file.lastModified() else 0L

        if (current != null && current.fileLastModified == lastModified) {
            return current.data
        }

        // Cache miss o file modificato fuori da save(): reload da disco.
        return try {
            if (!file.exists()) {
                val empty = emptyMap<String, LimitEntry>()
                cache.set(CachedSnapshot(empty, SystemClock.elapsedRealtime(), 0L))
                return empty
            }
            val json = JSONObject(file.readText())
            val out = mutableMapOf<String, LimitEntry>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val entry = parseEntry(json.opt(k)) ?: continue
                if (entry.minutes > 0) out[k] = entry
            }
            val frozen = out.toMap()
            cache.set(CachedSnapshot(frozen, SystemClock.elapsedRealtime(), lastModified))
            frozen
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read limits, returning empty", e)
            emptyMap()
        }
    }

    /// Parsa un singolo entry tollerando il formato legacy. Ritorna null se
    /// il valore è inutilizzabile.
    private fun parseEntry(raw: Any?): LimitEntry? = when (raw) {
        is Number -> LimitEntry(minutes = raw.toInt(), strict = true)
        is JSONObject -> {
            val m = raw.optInt("minutes", 0)
            // `strict` default true: per limiti già esistenti senza il
            // campo, hard cap è il comportamento più sicuro. L'utente
            // può sempre modificarlo dal picker.
            val s = raw.optBoolean("strict", true)
            LimitEntry(minutes = m, strict = s)
        }
        else -> null
    }

    fun save(context: Context, limits: Map<String, LimitEntry>) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val json = JSONObject()
            for ((k, v) in limits) {
                if (v.minutes <= 0) continue
                val obj = JSONObject().apply {
                    put("minutes", v.minutes)
                    put("strict", v.strict)
                }
                json.put(k, obj)
            }
            file.writeText(json.toString())
            // Aggiorna immediatamente la cache così il prossimo read non
            // deve nemmeno hit-are il filesystem per il check di lastModified.
            val frozen = limits.filter { it.value.minutes > 0 }.toMap()
            cache.set(CachedSnapshot(frozen, SystemClock.elapsedRealtime(), file.lastModified()))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save limits", e)
        }
    }

    fun limitMinutesFor(context: Context, packageName: String): Int =
        read(context)[packageName]?.minutes ?: 0

    fun isStrictFor(context: Context, packageName: String): Boolean =
        read(context)[packageName]?.strict ?: true

    fun entryFor(context: Context, packageName: String): LimitEntry? =
        read(context)[packageName]
}
