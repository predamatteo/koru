package com.dev.koru.service

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
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
 *   "_meta": {"last_reset_day": "2026-05-05", "last_reset_wall_ms": 1715000000000, "last_reset_elapsed_ms": 9876543}
 * }
 * ```
 *
 * ARCH-03/CR-04 — migrato su [FileBackedStore]:
 * - Prima la cache (`AtomicReference<JSONObject>`) **non si invalidava mai**
 *   (`readCached` ritornava l'istanza cache-ata senza controllare il file):
 *   il conteggio mostrato dal main process restava permanentemente stale
 *   rispetto agli `increment` fatti dal `:accessibility` (CR-04). Ora la cache
 *   è invalidata su `(mtime,length)`.
 * - Prima [increment]/[reset] mutavano IN PLACE il `JSONObject` condiviso in
 *   cache (`json.put`/`json.remove`) → data race tra i thread/processi (CR-04).
 *   Ora la mutazione è un read-modify-write su uno stato immutabile ([State]),
 *   sotto lock cross-process (copy-before-mutate per costruzione).
 * - Scrittura atomica (temp+rename) ereditata dall'astrazione (SEC-09).
 *
 * Anti clock-abuse sul rollover di giorno: il "giorno effettivo" usato per
 * decidere se il counter è "di oggi" è calcolato da [decideDay], che mirror-a la
 * guardia monotonica di [UsageGuardStore.decide]. Spostando l'orologio indietro
 * (stesso boot) o in avanti in modo incoerente, [decideDay] NON fa rollover →
 * il counter resta → più frizione. (Il caso reboot+salto-avanti combinato è
 * irrobustito in un commit successivo, SEC-05.)
 */
object BypassCountStore {
    private const val TAG = "BypassCountStore"
    private const val FILE_NAME = "koru_bypass_counts.json"
    private const val META_KEY = "_meta"
    private const val META_LAST_RESET_DAY = "last_reset_day"
    private const val META_LAST_RESET_WALL = "last_reset_wall_ms"
    private const val META_LAST_RESET_ELAPSED = "last_reset_elapsed_ms"

    /// Tolleranza tra wall delta e elapsed delta. Oltre questa differenza
    /// assumiamo manipolazione dell'orologio. 1h di slack copre NTP/DST/timezone
    /// legittimi (stesso valore concettuale di [UsageGuardStore]).
    internal const val TIME_DRIFT_TOLERANCE_MS = 60_000L + 3_600_000L // 1 min + 1 ora DST

    private val dateFormat: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    /// Contatore di un singolo package per un dato giorno.
    internal data class CountEntry(val date: String, val count: Int)

    /// Baseline temporale globale per la guardia anti clock-abuse.
    internal data class Meta(val lastResetDay: String, val lastWall: Long, val lastElapsed: Long)

    /// Stato IMMUTABILE dello store. Copy-before-mutate per costruzione: ogni
    /// mutazione produce una nuova [State] (niente in-place su strutture
    /// condivise → niente data race, CR-04).
    internal data class State(val entries: Map<String, CountEntry>, val meta: Meta?) {
        companion object {
            val EMPTY = State(emptyMap(), null)
        }
    }

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<State> {
            override fun serialize(value: State): String {
                val json = JSONObject()
                for ((pkg, e) in value.entries) {
                    json.put(
                        pkg,
                        JSONObject().apply {
                            put("date", e.date)
                            put("count", e.count)
                        },
                    )
                }
                value.meta?.let { m ->
                    json.put(
                        META_KEY,
                        JSONObject().apply {
                            put(META_LAST_RESET_DAY, m.lastResetDay)
                            put(META_LAST_RESET_WALL, m.lastWall)
                            put(META_LAST_RESET_ELAPSED, m.lastElapsed)
                        },
                    )
                }
                return json.toString()
            }

            override fun deserialize(raw: String): State {
                val json = JSONObject(raw)
                val entries = mutableMapOf<String, CountEntry>()
                var meta: Meta? = null
                val keys = json.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    val obj = json.optJSONObject(k) ?: continue
                    if (k == META_KEY) {
                        meta = Meta(
                            lastResetDay = obj.optString(META_LAST_RESET_DAY, ""),
                            lastWall = obj.optLong(META_LAST_RESET_WALL, 0L),
                            lastElapsed = obj.optLong(META_LAST_RESET_ELAPSED, 0L),
                        )
                    } else {
                        entries[k] = CountEntry(
                            date = obj.optString("date", ""),
                            count = obj.optInt("count", 0),
                        )
                    }
                }
                return State(entries.toMap(), meta)
            }
        },
        // Fail-secure: file corrotto ⇒ stato vuoto. Per il counter "vuoto"
        // significa friction al minimo: NON è la direzione anti-evasione più
        // dura, ma il bypass count NON è un hard cap (lo strict mode lo è, e
        // bypassa interamente questo path). È coerente col comportamento storico
        // (file corrotto → count 0) e non sblocca alcun limite.
        corruptFallback = { State.EMPTY },
    )

    /// Numero di bypass usati oggi per [packageName]. Ritorna 0 se la data
    /// salvata non è il giorno effettivo (o se nessun entry esiste). Read-only:
    /// non riscrive il file (il rollover materiale avviene al prossimo
    /// [increment]).
    fun todayCount(context: Context, packageName: String): Int {
        return try {
            val state = store.read(context)
            val entry = state.entries[packageName] ?: return 0
            if (entry.date != effectiveToday(state)) return 0
            entry.count
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read bypass count, returning 0", e)
            0
        }
    }

    /// Incrementa il counter di [packageName] e ritorna il nuovo valore.
    /// Se la data salvata non è il giorno effettivo, riparte da 1. RMW atomico
    /// sotto lock cross-process.
    fun increment(context: Context, packageName: String): Int {
        var result = 0
        try {
            store.mutate(context) { state ->
                val today = effectiveToday(state)
                val existing = state.entries[packageName]
                val newCount = if (existing == null || existing.date != today) 1 else existing.count + 1
                result = newCount

                val entries = state.entries.toMutableMap().apply {
                    this[packageName] = CountEntry(today, newCount)
                }
                // Aggiorna la baseline temporale solo al cambio di giorno (o al
                // primo write): così il prossimo check anti-tampering ha
                // riferimenti freschi senza spostarli a ogni increment.
                val meta = if (state.meta?.lastResetDay == today) {
                    state.meta
                } else {
                    Meta(
                        lastResetDay = today,
                        lastWall = System.currentTimeMillis(),
                        lastElapsed = SystemClock.elapsedRealtime(),
                    )
                }
                State(entries.toMap(), meta)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to increment bypass count", e)
            return 0
        }
        return result
    }

    /// Reset esplicito (utile per debug e per quando l'utente abilita lo
    /// strict mode su un'app — i contatori storici diventano irrilevanti).
    fun reset(context: Context, packageName: String) {
        try {
            store.mutate(context) { state ->
                if (!state.entries.containsKey(packageName)) {
                    state
                } else {
                    State(state.entries - packageName, state.meta)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to reset bypass count", e)
        }
    }

    /// Giorno EFFETTIVO da usare per il confronto col `date` salvato, applicando
    /// la guardia anti clock-abuse a partire dalla baseline in [State.meta].
    private fun effectiveToday(state: State): String =
        decideDay(
            rawToday = todayString(),
            meta = state.meta,
            latestSavedDate = latestSavedDate(state),
            nowWall = System.currentTimeMillis(),
            nowElapsed = SystemClock.elapsedRealtime(),
        )

    /**
     * Decisione PURA (nessun I/O / clock di sistema): dato il giorno wall grezzo
     * [rawToday], la baseline [meta] e i due orologi, ritorna il giorno da
     * considerare "oggi" per il counter.
     *
     * Mirror della guardia monotonica di [UsageGuardStore.decide]. Invariante di
     * sicurezza: il rollover a un giorno NUOVO (che azzererebbe la friction)
     * avviene SOLO se corroborato; in caso di ambiguità (stesso boot) si congela
     * al giorno salvato → più frizione.
     */
    internal fun decideDay(
        rawToday: String,
        meta: Meta?,
        latestSavedDate: String?,
        nowWall: Long,
        nowElapsed: Long,
    ): String {
        // Nessuna baseline (primo avvio o meta assente): non possiamo verificare
        // i clock → usiamo il wall grezzo (non c'è storia da proteggere).
        if (meta == null || meta.lastWall <= 0L || meta.lastElapsed <= 0L) return rawToday

        val savedDay = if (meta.lastResetDay.isNotEmpty()) meta.lastResetDay else (latestSavedDate ?: rawToday)
        // Giorno invariato rispetto alla baseline: niente rollover da decidere.
        if (savedDay == rawToday) return savedDay

        val wallDelta = nowWall - meta.lastWall
        val elapsedDelta = nowElapsed - meta.lastElapsed

        // Reboot: elapsedRealtime regredito (riparte da ~0 al boot). Il clock
        // monotonico NON è un riferimento per questo intervallo.
        val reboot = elapsedDelta < 0L

        // Salto wall indietro (stesso boot): l'utente ha riportato la data a
        // ieri per azzerare il counter → NON fare rollover, congela.
        val wallWentBack = !reboot && wallDelta < -TIME_DRIFT_TOLERANCE_MS

        // Salto wall in avanti incoerente (stesso boot): wall corre molto più
        // dell'elapsed reale → tentativo di "saltare" a un giorno fresco.
        val wallJumpedForward = !reboot && wallDelta > elapsedDelta + TIME_DRIFT_TOLERANCE_MS

        return when {
            // Anomalia del clock stesso-boot (avanti o indietro): congela al
            // giorno salvato → counter NON azzerato → più frizione.
            wallWentBack || wallJumpedForward -> savedDay

            // Reboot col giorno wall cambiato: gli UsageStats/wall sopravvivono
            // al riavvio e il monotonico non è un riferimento attraverso il
            // reboot → ci fidiamo del giorno wall (rollover). NB: questo ramo è
            // ancora vulnerabile a un salto wall in avanti combinato col reboot
            // (SEC-05), irrobustito in un commit successivo.
            reboot -> rawToday

            // Stesso boot, clock coerenti (|wallDelta - elapsedDelta| <= tol) e
            // wall non andato indietro: rollover di mezzanotte legittimo.
            kotlin.math.abs(wallDelta - elapsedDelta) <= TIME_DRIFT_TOLERANCE_MS -> rawToday

            // Default fail-secure: giorno cambiato ma clock sospetto → congela.
            else -> savedDay
        }
    }

    private fun latestSavedDate(state: State): String? {
        var latest: String? = null
        for ((_, e) in state.entries) {
            if (e.date.isNotEmpty() && (latest == null || e.date > latest!!)) latest = e.date
        }
        return latest
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

    // ---------------- test hooks ----------------

    internal fun invalidateCacheForTest() = store.invalidateCacheForTest()
}
