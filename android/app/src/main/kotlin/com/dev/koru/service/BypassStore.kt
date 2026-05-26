package com.dev.koru.service

import android.content.Context
import android.util.Log
import com.dev.koru.overlay.BlockReason
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption
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
 * l'utente; e gli auto-revoke non si coordinavano. Questo store mette la
 * fonte di verità su disco, condivisa.
 *
 * File: `filesDir/koru_bypasses.json`. Schema (scadenza su due orologi — vedi
 * [BypassEntry.isActive]):
 * ```
 * {
 *   "com.pkg":            {"untilWall": 1716700000000, "untilElapsed": 987654, "reason": "USAGE_LIMIT"},
 *   "com.pkg|reddit.com": {"untilWall": 1716700000000, "untilElapsed": 987654, "reason": "WEBSITE_BLOCKED"}
 * }
 * ```
 * La chiave è `package` (bypass app-wide) o `package|dominio` (bypass del
 * solo sito) — vedi `OverlayManager.bypassKey`.
 *
 * Concorrenza (hardening dopo security review del fix M2):
 * - Le LETTURE ([read], hot path: ogni accessibility event + ogni poll) usano
 *   una cache `AtomicReference` invalidata su `(lastModified, length)` del
 *   file — pattern di [AppUsageLimitsStore], esteso con `length` perché su FS
 *   con `mtime` a granularità di 1s due scritture nello stesso secondo non
 *   cambierebbero `lastModified`; la lunghezza quasi sempre sì.
 * - Le MUTAZIONI ([put]/[removePackage]/[clearAll]) sono un read-modify-write
 *   serializzato sia INTRA-processo (`synchronized(localLock)`) sia
 *   CROSS-processo (`FileChannel.lock` su un sidecar `.lock`). Senza il lock
 *   cross-process i due processi (che possono entrambi scrivere durante
 *   l'handoff di morte/rinascita dell'AccessibilityService) facevano
 *   last-writer-wins sull'INTERA mappa: una revoca poteva essere annullata da
 *   uno snapshot stale dell'altro processo → bypass "resuscitato" → cap esteso
 *   (fail-OPEN). Sotto lock leggiamo SEMPRE fresco da disco ([readFresh]) e
 *   scriviamo in modo ATOMICO (temp file + rename), così un reader concorrente
 *   vede o il file vecchio intero o il nuovo intero, mai uno torn.
 *
 * Fail-safe: errori di I/O o `reason` sconosciuto ⇒ nessun bypass / APP_BLOCKED
 * (un profilo-bypass non sospende il cap), cioè la direzione che mantiene il
 * blocco attivo. Il backup di sistema è disabilitato per questo file
 * (`allowBackup=false` + `fullBackupContent=false` nel manifest), quindi non è
 * estraibile/modificabile via `adb backup` su device non-root.
 */
object BypassStore {
    private const val TAG = "BypassStore"
    private const val FILE_NAME = "koru_bypasses.json"
    private const val TMP_NAME = "koru_bypasses.json.tmp"
    private const val LOCK_NAME = "koru_bypasses.json.lock"

    private data class CachedSnapshot(
        val data: Map<String, BypassEntry>,
        val fileLastModified: Long,
        val fileLength: Long,
    )

    private val cache = AtomicReference<CachedSnapshot?>(null)

    /// Serializza i read-modify-write DENTRO questo processo. Va preso PRIMA
    /// del file lock: `FileChannel.lock` lancia OverlappingFileLockException se
    /// lo stesso JVM tenta due lock sovrapposti, quindi i thread del processo
    /// devono accodarsi qui prima di contendere il lock cross-process.
    private val localLock = Any()

    /// Stato corrente (cache-based, NON prende il file lock — il write atomico
    /// garantisce che non si legga mai un file parziale). Include eventuali
    /// entry già scadute: i chiamanti in [OverlayManager] filtrano via
    /// [BypassEntry.isActive].
    fun read(context: Context): Map<String, BypassEntry> {
        val file = File(context.filesDir, FILE_NAME)
        val lastModified = file.lastModified() // 0L se il file non esiste
        val length = file.length()
        val current = cache.get()
        if (current != null &&
            current.fileLastModified == lastModified &&
            current.fileLength == length
        ) {
            return current.data
        }
        return loadFromDisk(file, lastModified, length)
    }

    private fun loadFromDisk(file: File, lastModified: Long, length: Long): Map<String, BypassEntry> {
        return try {
            if (!file.exists()) {
                val empty = emptyMap<String, BypassEntry>()
                cache.set(CachedSnapshot(empty, 0L, 0L))
                return empty
            }
            val json = JSONObject(file.readText())
            val out = mutableMapOf<String, BypassEntry>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val obj = json.optJSONObject(k) ?: continue
                val untilWall = obj.optLong("untilWall", 0L)
                if (untilWall <= 0L) continue
                val untilElapsed = obj.optLong("untilElapsed", 0L)
                out[k] = BypassEntry(untilWall, untilElapsed, parseReason(obj.optString("reason")))
            }
            val frozen = out.toMap()
            cache.set(CachedSnapshot(frozen, lastModified, length))
            frozen
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read bypasses, returning empty", e)
            emptyMap()
        }
    }

    /// Inserisce/aggiorna il bypass per [key], eliminando al volo le entry già
    /// scadute così il file non cresce indefinitamente.
    fun put(context: Context, key: String, entry: BypassEntry) = mutate(context) { current ->
        // Pota le entry non più attive (scadute su wall O su clock monotonico)
        // così il file non cresce.
        current.filterValues { it.isActive() }.toMutableMap().apply { this[key] = entry }
    }

    /// Rimuove il bypass app-wide (`packageName`) e TUTTE le varianti
    /// per-dominio (`packageName|*`). Simmetrico a `OverlayManager.clearBypass`.
    fun removePackage(context: Context, packageName: String) = mutate(context) { current ->
        val prefix = "$packageName|"
        current.filterKeys { it != packageName && !it.startsWith(prefix) }
    }

    fun clearAll(context: Context) = mutate(context) { emptyMap() }

    /// Read-modify-write atomico e serializzato cross-process. [transform]
    /// riceve lo stato FRESCO da disco (non la cache, che potrebbe essere
    /// stale rispetto a una scrittura dell'altro processo) e ritorna la nuova
    /// mappa; se non cambia nulla la scrittura viene saltata (no-op frequente
    /// nell'auto-revoke di un pkg non bypassato).
    private fun mutate(
        context: Context,
        transform: (Map<String, BypassEntry>) -> Map<String, BypassEntry>,
    ) {
        synchronized(localLock) {
            withFileLock(context) {
                val current = readFresh(context)
                val updated = transform(current)
                if (updated != current) writeAtomic(context, updated)
            }
        }
    }

    /// Legge SEMPRE da disco (bypassa la cache) e la aggiorna. Usato sotto file
    /// lock, dove dobbiamo vedere le scritture appena fatte dall'altro processo.
    private fun readFresh(context: Context): Map<String, BypassEntry> {
        val file = File(context.filesDir, FILE_NAME)
        return loadFromDisk(file, file.lastModified(), file.length())
    }

    private fun writeAtomic(context: Context, map: Map<String, BypassEntry>) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val tmp = File(context.filesDir, TMP_NAME)
            val json = JSONObject()
            for ((k, v) in map) {
                json.put(
                    k,
                    JSONObject().apply {
                        put("untilWall", v.untilWall)
                        put("untilElapsed", v.untilElapsed)
                        put("reason", v.reason.name)
                    },
                )
            }
            tmp.writeText(json.toString())
            try {
                Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
            } catch (e: Exception) {
                // FS senza move/replace (alcuni mount): fallback diretto. Meno
                // atomico ma il file resta valido (writeText scrive tutto).
                file.writeText(json.toString())
                tmp.delete()
            }
            cache.set(CachedSnapshot(map.toMap(), file.lastModified(), file.length()))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write bypasses", e)
        }
    }

    /// Lock di file CROSS-PROCESS sul sidecar `.lock`. Serializza i RMW tra
    /// `:accessibility` e main, chiudendo la resurrection/lost-revoke del
    /// bypass (security finding H1). Best-effort: se il lock non è disponibile
    /// (FS particolare, ambiente di test) degradiamo eseguendo comunque il
    /// body — [localLock] garantisce l'atomicità intra-processo. [body] viene
    /// eseguito ESATTAMENTE una volta in ogni ramo.
    private fun withFileLock(context: Context, body: () -> Unit) {
        val raf = try {
            RandomAccessFile(File(context.filesDir, LOCK_NAME), "rw")
        } catch (e: Exception) {
            Log.w(TAG, "Cannot open lock file, proceeding best-effort", e)
            body()
            return
        }
        raf.use {
            val lock = try {
                it.channel.lock()
            } catch (e: Exception) {
                Log.w(TAG, "Cannot acquire cross-process lock, proceeding best-effort", e)
                null
            }
            try {
                body()
            } finally {
                try { lock?.release() } catch (_: Exception) {}
            }
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
