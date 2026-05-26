package com.dev.koru.service

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject

/**
 * SEC-03 — guardia monotonica anti clock-backward sul cap giornaliero "hard".
 *
 * Problema (SEC-03, near-Critical): [UsageCounter.todayForegroundMs] definisce
 * "oggi" col WALL clock ([Calendar.getInstance]). Spostando la DATA indietro di
 * un giorno la finestra "da mezzanotte a ora" cade su tempo passato, la query
 * `queryEvents` ritorna ~0, e il cap strict (hard cap che ignora ogni bypass)
 * NON scatta più → l'app capata si sblocca. È lo stesso attacco contro cui
 * [BypassStore]/[BypassCountStore] sono stati irrobustiti, ma che la logica del
 * cap non eredita.
 *
 * Difesa: uno store cross-process (pattern [BypassStore]: scrittura atomica
 * temp+rename, lock di file, cache invalidata su `(mtime,len)`) che persiste
 * per-package `{day, accumMs}` e un meta globale `{lastWall, lastElapsed}`.
 * Ad ogni check del cap [observe] confronta i delta dei due orologi:
 *
 * - **Stesso giorno** (clock coerenti): `effettivo = max(raw, accumulato)`.
 *   L'uso entro un giorno è monotòno non-decrescente: il `max` impedisce che
 *   un raw "sceso" (per un glitch del clock) abbassi il contatore.
 * - **Salto WALL indietro** (`elapsed avanza ~normale ma wall torna indietro`):
 *   NON facciamo rollover di giorno; **portiamo avanti** l'accumulato del
 *   giorno precedente (`effettivo = max(raw, accumulato)`) così il cap resta
 *   scattato. È il cuore di SEC-03.
 * - **Salto WALL in avanti incoerente** (wallDelta ≫ elapsedDelta): idem, NON
 *   facciamo rollover (un avversario non "salta" a un giorno fresco con uso 0).
 * - **Rollover di mezzanotte LEGITTIMO** (giorno cambiato E `wallDelta ≈
 *   elapsedDelta`, entro tolleranza — `elapsedRealtime` conta anche il deep
 *   sleep, quindi entro lo stesso boot i due delta coincidono per il tempo
 *   reale): giorno nuovo, `effettivo = raw`, accumulato ripartito.
 * - **Reboot** (`elapsedRealtime` ripartito da 0 → elapsedDelta<0): il clock
 *   monotonico non è un riferimento per questo intervallo, ma gli UsageStats
 *   sono ancorati al wall e sopravvivono al riavvio → ci fidiamo del giorno
 *   wall (rollover se cambiato), accumulando entro il giorno.
 *
 * Limite residuo documentato: reboot + salto wall in avanti combinati possono,
 * come per SEC-04, far rollover a un giorno "fresco". È un attacco ad alto
 * sforzo; il cap resta comunque la difesa più forte e gli UsageStats non sono
 * falsificabili.
 *
 * File: `filesDir/koru_usage_guard.json`. allowBackup=false copre anche questo.
 */
object UsageGuardStore {
    private const val TAG = "UsageGuardStore"
    private const val FILE_NAME = "koru_usage_guard.json"
    private const val TMP_NAME = "koru_usage_guard.json.tmp"
    private const val LOCK_NAME = "koru_usage_guard.json.lock"

    private const val META_KEY = "_meta"
    private const val META_LAST_WALL = "last_wall_ms"
    private const val META_LAST_ELAPSED = "last_elapsed_ms"

    /// Tolleranza tra wallDelta ed elapsedDelta. Oltre questa differenza
    /// assumiamo manomissione del wall clock (NTP/timezone legittimi rientrano;
    /// 1h di slack copre i salti DST). Sotto soglia i due orologi "concordano".
    const val TIME_DRIFT_TOLERANCE_MS = 60_000L + 3_600_000L // 1 min + 1 ora DST

    private data class CachedSnapshot(
        val json: JSONObject,
        val fileLastModified: Long,
        val fileLength: Long,
    )

    private val cache = AtomicReference<CachedSnapshot?>(null)
    private val localLock = Any()

    private val dateFormat: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    /// Esito puro della decisione di guardia. [effectiveMs] è il valore da
    /// confrontare col cap; gli altri campi sono lo stato da persistere.
    internal data class Decision(
        val effectiveMs: Long,
        val day: String,
        val accumMs: Long,
    )

    /// Registra un'osservazione del cap per [packageName] con il [rawMs]
    /// calcolato wall-based da [UsageCounter], applica la guardia monotonica e
    /// ritorna i ms EFFETTIVI da confrontare col cap. Aggiorna lo store.
    fun observe(context: Context, packageName: String, rawMs: Long): Long {
        return try {
            val nowWall = System.currentTimeMillis()
            val nowElapsed = SystemClock.elapsedRealtime()
            val realToday = todayString(nowWall)
            var effective = rawMs
            mutate(context) { json ->
                val meta = json.optJSONObject(META_KEY)
                val lastWall = meta?.optLong(META_LAST_WALL, 0L) ?: 0L
                val lastElapsed = meta?.optLong(META_LAST_ELAPSED, 0L) ?: 0L
                val entry = json.optJSONObject(packageName)
                val savedDay = entry?.optString("day", "") ?: ""
                val savedAccum = entry?.optLong("accumMs", 0L) ?: 0L

                val decision = decide(
                    rawMs = rawMs,
                    savedDay = savedDay,
                    savedAccumMs = savedAccum,
                    realToday = realToday,
                    lastWall = lastWall,
                    lastElapsed = lastElapsed,
                    nowWall = nowWall,
                    nowElapsed = nowElapsed,
                )
                effective = decision.effectiveMs

                // Scrivi lo stato aggiornato (entry pkg + meta clock).
                json.put(
                    packageName,
                    JSONObject().apply {
                        put("day", decision.day)
                        put("accumMs", decision.accumMs)
                    },
                )
                json.put(
                    META_KEY,
                    JSONObject().apply {
                        put(META_LAST_WALL, nowWall)
                        put(META_LAST_ELAPSED, nowElapsed)
                    },
                )
                json
            }
            effective
        } catch (e: Exception) {
            // Fail-secure: in caso di errore non ABBASSIAMO mai il valore reale.
            Log.w(TAG, "Usage guard failed, returning raw", e)
            rawMs
        }
    }

    /// Reset esplicito per [packageName] (es. quando l'utente cambia il limite
    /// o disabilita lo strict su quell'app: la storia diventa irrilevante).
    fun reset(context: Context, packageName: String) {
        try {
            mutate(context) { json ->
                json.remove(packageName)
                json
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to reset usage guard for $packageName", e)
        }
    }

    /**
     * SEC-03 — decisione PURA (nessun I/O / clock): dato il [rawMs] wall-based,
     * lo stato salvato e i due orologi, ritorna i ms effettivi + lo stato nuovo.
     *
     * Invariante di sicurezza: l'effettivo NON scende mai per un'anomalia del
     * clock; l'unico azzeramento è un rollover di mezzanotte corroborato.
     */
    internal fun decide(
        rawMs: Long,
        savedDay: String,
        savedAccumMs: Long,
        realToday: String,
        lastWall: Long,
        lastElapsed: Long,
        nowWall: Long,
        nowElapsed: Long,
    ): Decision {
        // Primo avvio assoluto (nessuna entry pkg): inizializza al raw odierno.
        if (savedDay.isEmpty()) {
            return Decision(effectiveMs = rawMs, day = realToday, accumMs = rawMs)
        }

        val wallDelta = nowWall - lastWall
        val elapsedDelta = nowElapsed - lastElapsed
        val haveMeta = lastWall > 0L && lastElapsed > 0L

        // Reboot: elapsedRealtime regredito. UsageStats restano validi (wall-
        // anchored) → fidati del giorno wall; nessun riferimento monotonico.
        val reboot = haveMeta && elapsedDelta < 0L

        // Salto wall indietro (stesso boot): elapsed avanza ~normale ma il wall
        // torna indietro oltre tolleranza. È l'attacco SEC-03.
        val wallWentBack = haveMeta && !reboot && wallDelta < -TIME_DRIFT_TOLERANCE_MS

        // Salto wall in avanti incoerente (stesso boot): wall corre molto più
        // dell'elapsed reale → tentativo di "saltare" a un giorno fresco.
        val wallJumpedForward = haveMeta && !reboot &&
            wallDelta > elapsedDelta + TIME_DRIFT_TOLERANCE_MS

        val sameDay = savedDay == realToday

        return when {
            // Anomalia del clock (avanti o indietro, stesso boot): congela il
            // giorno salvato e PORTA AVANTI l'accumulato → cap resta scattato.
            wallWentBack || wallJumpedForward -> {
                val eff = maxOf(rawMs, savedAccumMs)
                Decision(effectiveMs = eff, day = savedDay, accumMs = eff)
            }

            // Stesso giorno (clock coerenti o reboot nello stesso giorno):
            // accumula, mai scendere.
            sameDay -> {
                val eff = maxOf(rawMs, savedAccumMs)
                Decision(effectiveMs = eff, day = savedDay, accumMs = eff)
            }

            // Giorno cambiato. Rollover LEGITTIMO solo se:
            //  - reboot (UsageStats wall-anchored, fidati del giorno), oppure
            //  - i due orologi concordano (|wallDelta - elapsedDelta| <= tol)
            //    e il wall non è andato indietro.
            reboot || (haveMeta && kotlin.math.abs(wallDelta - elapsedDelta) <= TIME_DRIFT_TOLERANCE_MS) ||
                !haveMeta -> {
                Decision(effectiveMs = rawMs, day = realToday, accumMs = rawMs)
            }

            // Default fail-secure: giorno cambiato ma clock sospetto → congela.
            else -> {
                val eff = maxOf(rawMs, savedAccumMs)
                Decision(effectiveMs = eff, day = savedDay, accumMs = eff)
            }
        }
    }

    // ---------------- persistenza (pattern BypassStore) ----------------

    private fun mutate(context: Context, transform: (JSONObject) -> JSONObject) {
        synchronized(localLock) {
            withFileLock(context) {
                val current = readFresh(context)
                val updated = transform(current)
                writeAtomic(context, updated)
            }
        }
    }

    private fun readFresh(context: Context): JSONObject {
        val file = File(context.filesDir, FILE_NAME)
        return try {
            if (!file.exists()) JSONObject() else JSONObject(file.readText())
        } catch (e: Exception) {
            Log.w(TAG, "Corrupt usage guard file, starting fresh", e)
            JSONObject()
        }
    }

    private fun writeAtomic(context: Context, json: JSONObject) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val tmp = File(context.filesDir, TMP_NAME)
            val text = json.toString()
            tmp.writeText(text)
            try {
                Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
            } catch (e: Exception) {
                file.writeText(text)
                tmp.delete()
            }
            cache.set(CachedSnapshot(JSONObject(text), file.lastModified(), file.length()))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write usage guard", e)
        }
    }

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

    private fun todayString(nowWall: Long): String {
        val cal = Calendar.getInstance().apply {
            timeInMillis = nowWall
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return dateFormat.format(Date(cal.timeInMillis))
    }
}
