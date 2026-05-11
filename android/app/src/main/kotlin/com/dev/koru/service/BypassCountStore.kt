package com.dev.koru.service

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject

/**
 * Counter giornaliero dei bypass per-package. Persistito su file in modo
 * cross-process: il main process può leggerlo per UI (es. "bypassed N
 * times today"), il processo `:accessibility` lo incrementa quando
 * l'utente conferma il duration picker e lo legge per calcolare la
 * progressive friction (countdown crescente, durate decrescenti).
 *
 * File: `filesDir/koru_bypass_counts.json`.
 * Schema:
 * ```
 * {
 *   "com.pkg": {"date": "2026-05-05", "count": 3},
 *   "_meta": {"last_reset_wall_ms": 1715000000000, "last_reset_elapsed_ms": 9876543}
 * }
 * ```
 *
 * Hardening (S6):
 * - Cache `AtomicReference<JSONObject>` per evitare file I/O ad ogni
 *   query: il polling del :accessibility (1Hz) chiamava `todayCount` a
 *   ogni iterazione, causando re-parse del JSON ogni secondo. Ora la
 *   prima read mette in cache, le successive vanno a memoria.
 *   La cache è invalidata su write (increment/reset).
 * - Anti-time-manipulation: salviamo `last_reset_wall_ms` + `last_reset_elapsed_ms`.
 *   Se l'utente sposta l'orologio indietro per "guadagnare" un nuovo
 *   giorno e resettare il counter, il delta elapsed (monotonic) non
 *   coincide col delta wall e rifiutiamo il reset.
 *
 * Il reset è implicito: se la data salvata non corrisponde a oggi,
 * `todayCount` ritorna 0 senza riscrivere il file (la riscrittura avviene
 * al primo `increment` del nuovo giorno).
 */
object BypassCountStore {
    private const val TAG = "BypassCountStore"
    private const val FILE_NAME = "koru_bypass_counts.json"
    private const val META_KEY = "_meta"
    private const val META_LAST_RESET_WALL = "last_reset_wall_ms"
    private const val META_LAST_RESET_ELAPSED = "last_reset_elapsed_ms"

    /// Tolleranza tra wall delta e elapsed delta. Se differiscono per più di
    /// questa quantità, assumiamo che l'utente abbia manipolato l'orologio
    /// e non resettiamo il counter giornaliero.
    private const val TIME_DRIFT_TOLERANCE_MS = 60_000L

    private val dateFormat: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    /// In-memory cache cross-process. Ogni processo (main + :accessibility)
    /// ha il suo, ma il file su disco è la fonte di verità: le write da un
    /// processo invalidano la cache del PROPRIO processo solo dopo la
    /// successiva read fresca. Per Koru va bene perché le scritture sono
    /// quasi sempre fatte dal :accessibility (increment al duration picker)
    /// e il main legge raramente (UI).
    private val cache = AtomicReference<JSONObject?>(null)

    /// Numero di bypass usati oggi per [packageName]. Ritorna 0 se la data
    /// salvata non è oggi (o se nessun entry esiste).
    fun todayCount(context: Context, packageName: String): Int {
        return try {
            val json = readCached(context) ?: return 0
            val obj = json.optJSONObject(packageName) ?: return 0
            val date = obj.optString("date", "")
            if (date != safeTodayString(context, json)) return 0
            obj.optInt("count", 0)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read bypass count, returning 0", e)
            0
        }
    }

    /// Incrementa il counter di [packageName] e ritorna il nuovo valore.
    /// Se la data salvata non è oggi, riparte da 1.
    fun increment(context: Context, packageName: String): Int {
        return try {
            val json = readCached(context) ?: JSONObject()
            val today = safeTodayString(context, json)
            val existing = json.optJSONObject(packageName)
            val newCount = if (existing == null || existing.optString("date") != today) {
                1
            } else {
                existing.optInt("count", 0) + 1
            }
            json.put(packageName, JSONObject().apply {
                put("date", today)
                put("count", newCount)
            })
            // Aggiorna meta solo se è effettivamente cambiato il giorno o
            // se è il primo write (no meta record). Track baseline temporali
            // così il prossimo check anti-tampering ha riferimenti freschi.
            updateMetaIfDayChanged(json, today)
            persist(context, json)
            newCount
        } catch (e: Exception) {
            Log.e(TAG, "Failed to increment bypass count", e)
            0
        }
    }

    /// Reset esplicito (utile per debug e per quando l'utente abilita lo
    /// strict mode su un'app — i contatori storici diventano irrilevanti).
    fun reset(context: Context, packageName: String) {
        try {
            val json = readCached(context) ?: return
            json.remove(packageName)
            persist(context, json)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to reset bypass count", e)
        }
    }

    /// Calcola la string di oggi usando wall clock, MA prima verifica che
    /// l'utente non abbia spostato l'orologio. Se rileva manipulation,
    /// "congela" il giorno al valore precedentemente salvato.
    private fun safeTodayString(context: Context, json: JSONObject): String {
        val rawToday = todayString()
        val meta = json.optJSONObject(META_KEY)
        if (meta == null) {
            // Prima volta: salviamo subito baseline.
            return rawToday
        }
        val lastWall = meta.optLong(META_LAST_RESET_WALL, 0L)
        val lastElapsed = meta.optLong(META_LAST_RESET_ELAPSED, 0L)
        if (lastWall == 0L || lastElapsed == 0L) return rawToday

        val nowWall = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        val wallDelta = nowWall - lastWall
        val elapsedDelta = nowElapsed - lastElapsed

        // Caso 1: wall andato indietro → user ha spostato l'orologio indietro
        // (probabilmente per resettare il counter). Tieni la data di ieri.
        if (wallDelta < -TIME_DRIFT_TOLERANCE_MS) {
            Log.w(TAG, "Wall clock moved backward (${wallDelta}ms vs elapsed ${elapsedDelta}ms) — freezing day")
            // Ritorna l'ultimo `date` letto da un qualsiasi entry come fallback.
            return latestSavedDate(json) ?: rawToday
        }

        // Caso 2: elapsed non è monotone-greater di wall (reboot non spiegherebbe
        // questa direzione). Se wall avanza molto più velocemente di elapsed
        // (wall - elapsed delta > tolerance), user ha portato avanti l'orologio
        // per "scappare" a un lockout. Idem: congela.
        // Eccezione: dopo un reboot, elapsed riparte da 0 → elapsedDelta è
        // negativo o piccolissimo, ma wallDelta è grande. In quel caso ci
        // fidiamo del wall (è la situazione "real" più comune).
        val rebootDetected = elapsedDelta < 0L || elapsedDelta < wallDelta - 3600_000L
        if (!rebootDetected && wallDelta > elapsedDelta + TIME_DRIFT_TOLERANCE_MS + 3600_000L) {
            // Tolleranza extra di 1 ora per NTP sync legittimi (cambio di
            // timezone, daylight saving). Sopra quella soglia → manipulation.
            Log.w(TAG, "Wall clock moved forward unrealistically (${wallDelta}ms vs ${elapsedDelta}ms elapsed)")
            return latestSavedDate(json) ?: rawToday
        }

        return rawToday
    }

    private fun latestSavedDate(json: JSONObject): String? {
        val keys = json.keys()
        var latest: String? = null
        while (keys.hasNext()) {
            val k = keys.next()
            if (k == META_KEY) continue
            val entry = json.optJSONObject(k) ?: continue
            val date = entry.optString("date", "")
            if (date.isNotEmpty() && (latest == null || date > latest)) {
                latest = date
            }
        }
        return latest
    }

    private fun updateMetaIfDayChanged(json: JSONObject, today: String) {
        val meta = json.optJSONObject(META_KEY)
        val previousDay = meta?.optString("last_reset_day", "") ?: ""
        if (previousDay == today && meta != null) return
        json.put(META_KEY, JSONObject().apply {
            put("last_reset_day", today)
            put(META_LAST_RESET_WALL, System.currentTimeMillis())
            put(META_LAST_RESET_ELAPSED, SystemClock.elapsedRealtime())
        })
    }

    private fun readCached(context: Context): JSONObject? {
        cache.get()?.let { return it }
        return try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return null
            val parsed = JSONObject(file.readText())
            cache.set(parsed)
            parsed
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load bypass counts from disk", e)
            null
        }
    }

    private fun persist(context: Context, json: JSONObject) {
        val file = File(context.filesDir, FILE_NAME)
        file.writeText(json.toString())
        cache.set(json)
    }

    private fun todayString(): String {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return dateFormat.format(Date(cal.timeInMillis))
    }
}
