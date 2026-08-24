package com.dev.koru.service

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

/**
 * Contatore giornaliero dei reel scrollati, per sorgente
 * (`INSTAGRAM_REELS`, `YOUTUBE_SHORTS`), con storico degli ultimi
 * [MAX_HISTORY_DAYS] giorni.
 *
 * File: `filesDir/koru_reel_counts.json`
 * ```
 * {
 *   "dayStart": 1755129600000,
 *   "counts": {"INSTAGRAM_REELS": 84, "YOUTUBE_SHORTS": 48},
 *   "history": [{"dayStart": 1755043200000, "counts": {...}}, ...]
 * }
 * ```
 *
 * ## Perché un file e non Drift
 * Il contatore viene incrementato dal motore di enforcement e letto dal widget
 * home, che per contratto **non tocca né Drift né i platform channel** (vedi la
 * nota di classe di [com.dev.koru.widget.KoruUsageWidgetProvider]). Un
 * [FileBackedStore] è l'unico posto che entrambi possono leggere senza tirarsi
 * dietro il runtime Flutter, ed è lo stesso pattern di [AppUsageLimitsStore] e
 * [BypassCountStore].
 *
 * ## Write-behind: perché non si scrive a ogni reel
 * Un incremento per swipe significherebbe una scrittura atomica (temp file +
 * rename + fsync implicito) ogni ~2 secondi durante una sessione di scrolling,
 * sul thread che deve anche far comparire l'overlay di blocco. I conteggi si
 * accumulano quindi in memoria e vengono versati su disco ogni
 * [FLUSH_EVERY_COUNTS] reel o [FLUSH_INTERVAL_MS], più un flush esplicito nei
 * momenti in cui la sessione finisce davvero (schermo spento, uscita dall'app).
 * Il prezzo è dichiarato: un kill del processo può perdere fino a
 * [FLUSH_EVERY_COUNTS] conteggi. Per una statistica di benessere è un
 * compromesso corretto — per un dato di enforcement non lo sarebbe.
 *
 * ## Rollover di mezzanotte
 * Il giorno è la mezzanotte LOCALE ([localDayStart]), calcolata con [Calendar]
 * come in [UsageCounter], quindi robusta al DST. A differenza di
 * [BypassCountStore] **non** c'è guardia monotonica anti clock-abuse: lì il
 * rollover azzera la frizione (spostare l'orologio sarebbe un bypass
 * dell'enforcement), qui azzera solo un numero che l'utente guarda. Chi sposta
 * l'orologio per vedere "0 reel oggi" sta ingannando se stesso, non il blocco.
 */
object ReelCountStore {
    private const val TAG = "ReelCountStore"
    private const val FILE_NAME = "koru_reel_counts.json"

    private const val KEY_DAY_START = "dayStart"
    private const val KEY_COUNTS = "counts"
    private const val KEY_HISTORY = "history"

    /// Quanti giorni passati teniamo. 30 copre la vista "ultimo mese" e tiene
    /// il file sotto il paio di KB, che è ciò che rende gratuita la lettura
    /// cache-ata sul percorso del widget.
    internal const val MAX_HISTORY_DAYS = 30

    /// Reel accumulati oltre i quali si versa su disco.
    internal const val FLUSH_EVERY_COUNTS = 5

    /// Tempo massimo per cui un conteggio resta solo in memoria.
    internal const val FLUSH_INTERVAL_MS = 30_000L

    /// Conteggi di un singolo giorno. [dayStartMs] è la mezzanotte locale.
    data class DayCounts(val dayStartMs: Long, val counts: Map<String, Int>) {
        val total: Int get() = counts.values.sum()
    }

    internal data class State(val today: DayCounts, val history: List<DayCounts>) {
        companion object {
            val EMPTY = State(DayCounts(0L, emptyMap()), emptyList())
        }
    }

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<State> {
            override fun serialize(value: State): String = encode(value)
            override fun deserialize(raw: String): State = decode(raw)
        },
        // File assente o illeggibile ⇒ si riparte da zero. Non è enforcement:
        // perdere lo storico di una statistica è preferibile a propagare un
        // parse error dentro il motore di blocco.
        corruptFallback = { State.EMPTY },
    )

    // ── Buffer write-behind ────────────────────────────────────────────────
    // Protetto da [pendingLock]: [add] arriva dal thread degli eventi di
    // accessibilità, le letture dal worker del widget e dal main thread
    // (platform channel).

    private val pendingLock = Any()
    private var pendingDayStart = 0L
    private val pending = HashMap<String, Int>()
    private var pendingTotal = 0
    private var pendingSinceUptimeMs = 0L

    /**
     * Accredita [delta] reel alla sorgente [sectionWireId] (il `wireId` di
     * [com.dev.koru.content.DetectedSection]).
     *
     * Sicura da chiamare sull'hot path: nel caso normale è un aggiornamento di
     * HashMap sotto lock, e tocca il disco solo quando scatta la politica di
     * flush.
     */
    fun add(context: Context, sectionWireId: String, delta: Int) {
        if (delta <= 0) return
        val day = localDayStart(System.currentTimeMillis())
        val now = SystemClock.uptimeMillis()
        synchronized(pendingLock) {
            // Il buffer appartiene a un giorno preciso: se la mezzanotte è
            // passata mentre stavamo accumulando, quei reel sono di IERI e
            // vanno versati prima di aprire il buffer nuovo. Senza questo,
            // scrollare a cavallo delle 00:00 sposterebbe la coda della sera
            // sul giorno dopo.
            if (pending.isNotEmpty() && day != pendingDayStart) flushLocked(context)
            if (pending.isEmpty()) {
                pendingDayStart = day
                pendingSinceUptimeMs = now
            }
            pending[sectionWireId] = (pending[sectionWireId] ?: 0) + delta
            pendingTotal += delta
            if (pendingTotal >= FLUSH_EVERY_COUNTS ||
                now - pendingSinceUptimeMs >= FLUSH_INTERVAL_MS
            ) {
                flushLocked(context)
            }
        }
    }

    /**
     * Versa su disco i conteggi ancora in memoria. Da chiamare quando la
     * sessione di scrolling finisce (schermo spento, utente uscito dall'app) e
     * prima di leggere il dato da un altro processo.
     *
     * @return `true` se non c'era nulla da scrivere o se la scrittura è
     *   riuscita.
     */
    fun flush(context: Context): Boolean = synchronized(pendingLock) { flushLocked(context) }

    /// Richiede il lock già preso.
    private fun flushLocked(context: Context): Boolean {
        if (pending.isEmpty()) return true
        val day = pendingDayStart
        val delta = HashMap(pending)
        val ok = try {
            store.mutate(context) { merge(it, day, delta, MAX_HISTORY_DAYS) }
        } catch (e: Exception) {
            Log.w(TAG, "flush dei conteggi reel fallito", e)
            false
        }
        if (ok) {
            pending.clear()
            pendingTotal = 0
        } else {
            // Teniamo i conteggi per ritentare, ma facciamo ripartire la
            // finestra: senza, ogni add successiva ritenterebbe la scrittura
            // (la soglia resta superata) e un disco pieno diventerebbe un ciclo
            // di I/O fallito sull'hot path.
            pendingTotal = 0
            pendingSinceUptimeMs = SystemClock.uptimeMillis()
        }
        return ok
    }

    /**
     * Conteggi di oggi per sorgente, **inclusi** quelli non ancora versati su
     * disco: il widget e la home devono mostrare l'ultimo reel scrollato, non
     * l'ultimo flush.
     */
    fun todayCounts(context: Context): Map<String, Int> {
        val day = localDayStart(System.currentTimeMillis())
        // Persistito e pending letti sotto lo STESSO lock. Farlo in due tempi
        // aprirebbe una finestra in cui un flush concorrente sposta dei
        // conteggi da un lato all'altro e questi vengono contati due volte (o
        // nessuna). La `read` è cache-ata su (mtime,length), quindi nel caso
        // normale qui dentro non c'è I/O.
        synchronized(pendingLock) {
            val persisted = readState(context)
            val out = HashMap<String, Int>()
            if (persisted.today.dayStartMs == day) out.putAll(persisted.today.counts)
            if (pendingDayStart == day) {
                for ((key, value) in pending) out[key] = (out[key] ?: 0) + value
            }
            return out
        }
    }

    /// Totale dei reel di oggi su tutte le sorgenti.
    fun todayTotal(context: Context): Int = todayCounts(context).values.sum()

    /**
     * Gli ultimi [maxDays] giorni, dal più recente al più vecchio, con i giorni
     * senza scrolling riempiti a zero — così un grafico non deve indovinare i
     * buchi. Il primo elemento è oggi e include il buffer non ancora versato.
     */
    fun recentDays(context: Context, maxDays: Int): List<DayCounts> {
        if (maxDays <= 0) return emptyList()
        val today = localDayStart(System.currentTimeMillis())
        val byDay = HashMap<Long, Map<String, Int>>()
        synchronized(pendingLock) {
            val persisted = readState(context)
            for (day in persisted.history) byDay[day.dayStartMs] = day.counts
            byDay[persisted.today.dayStartMs] = persisted.today.counts
            if (pendingDayStart != 0L) {
                val base = byDay[pendingDayStart] ?: emptyMap()
                val merged = HashMap(base)
                for ((key, value) in pending) merged[key] = (merged[key] ?: 0) + value
                byDay[pendingDayStart] = merged
            }
        }
        val out = ArrayList<DayCounts>(maxDays)
        var day = today
        repeat(maxDays) {
            out.add(DayCounts(day, byDay[day] ?: emptyMap()))
            day = previousLocalDayStart(day)
        }
        return out
    }

    /// Azzera contatori e storico (usata dal reset dei dati e dai test).
    fun clear(context: Context): Boolean = synchronized(pendingLock) {
        pending.clear()
        pendingTotal = 0
        pendingDayStart = 0L
        store.write(context, State.EMPTY)
    }

    private fun readState(context: Context): State = try {
        store.read(context)
    } catch (e: Exception) {
        Log.w(TAG, "lettura dei conteggi reel fallita", e)
        State.EMPTY
    }

    // ── Logica pura di merge (testabile senza Android) ─────────────────────

    /**
     * Applica [delta] al giorno [day] dentro [state].
     *
     * I tre casi non sono simmetrici e vale la pena esplicitarli:
     *  - **stesso giorno**: somma nei conteggi correnti;
     *  - **giorno più recente**: il giorno corrente diventa storia (se ha
     *    conteggi: un giorno a zero non merita una riga) e si riparte;
     *  - **giorno più vecchio**: succede quando un buffer accumulato prima di
     *    mezzanotte viene versato dopo che un altro flush ha già aperto il
     *    giorno nuovo. Quei reel appartengono alla sera precedente e vanno
     *    nella riga di storia giusta, non attribuiti a oggi.
     */
    internal fun merge(
        state: State,
        day: Long,
        delta: Map<String, Int>,
        maxHistoryDays: Int,
    ): State {
        if (delta.isEmpty() || day <= 0L) return state
        return when {
            day == state.today.dayStartMs ->
                state.copy(today = DayCounts(day, plus(state.today.counts, delta)))

            day > state.today.dayStartMs -> {
                val archived = if (state.today.counts.isEmpty()) {
                    state.history
                } else {
                    listOf(state.today) + state.history
                }
                State(
                    today = DayCounts(day, delta.filterValues { it > 0 }),
                    history = trim(archived, maxHistoryDays),
                )
            }

            else -> {
                val history = ArrayList(state.history)
                val at = history.indexOfFirst { it.dayStartMs == day }
                if (at >= 0) {
                    history[at] = DayCounts(day, plus(history[at].counts, delta))
                } else {
                    history.add(DayCounts(day, delta.filterValues { it > 0 }))
                    history.sortByDescending { it.dayStartMs }
                }
                state.copy(history = trim(history, maxHistoryDays))
            }
        }
    }

    private fun plus(base: Map<String, Int>, delta: Map<String, Int>): Map<String, Int> {
        val out = HashMap(base)
        for ((key, value) in delta) {
            if (value <= 0) continue
            out[key] = (out[key] ?: 0) + value
        }
        return out
    }

    private fun trim(history: List<DayCounts>, maxHistoryDays: Int): List<DayCounts> =
        if (history.size <= maxHistoryDays) history else history.take(maxHistoryDays)

    // ── Codec JSON ────────────────────────────────────────────────────────

    private fun encode(state: State): String {
        val history = JSONArray()
        for (day in state.history) history.put(encodeDay(day))
        return JSONObject()
            .put(KEY_DAY_START, state.today.dayStartMs)
            .put(KEY_COUNTS, encodeCounts(state.today.counts))
            .put(KEY_HISTORY, history)
            .toString()
    }

    private fun encodeDay(day: DayCounts): JSONObject = JSONObject()
        .put(KEY_DAY_START, day.dayStartMs)
        .put(KEY_COUNTS, encodeCounts(day.counts))

    /// Costruito a mano invece che con `JSONObject(Map)`: quel costruttore è
    /// raw-typed e in Kotlin richiede un cast che, se il tipo cambia, fallisce
    /// a runtime invece che a compile time.
    private fun encodeCounts(counts: Map<String, Int>): JSONObject {
        val json = JSONObject()
        for ((key, value) in counts) json.put(key, value)
        return json
    }

    private fun decode(raw: String): State {
        val json = JSONObject(raw)
        val today = DayCounts(
            dayStartMs = json.optLong(KEY_DAY_START, 0L),
            counts = decodeCounts(json.optJSONObject(KEY_COUNTS)),
        )
        val historyJson = json.optJSONArray(KEY_HISTORY)
        val history = ArrayList<DayCounts>(historyJson?.length() ?: 0)
        if (historyJson != null) {
            for (i in 0 until historyJson.length()) {
                val entry = historyJson.optJSONObject(i) ?: continue
                history.add(
                    DayCounts(
                        dayStartMs = entry.optLong(KEY_DAY_START, 0L),
                        counts = decodeCounts(entry.optJSONObject(KEY_COUNTS)),
                    ),
                )
            }
        }
        return State(today, history)
    }

    private fun decodeCounts(json: JSONObject?): Map<String, Int> {
        if (json == null) return emptyMap()
        val out = HashMap<String, Int>(json.length())
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.optInt(key, 0)
            if (value > 0) out[key] = value
        }
        return out
    }

    // ── Confini di giornata ───────────────────────────────────────────────

    /// Mezzanotte locale di [ts]. Stessa costruzione di [UsageCounter]: via
    /// [Calendar] e non con un offset fisso di 24h, così DST e cambi di fuso
    /// non spostano il confine.
    internal fun localDayStart(ts: Long): Long = Calendar.getInstance().apply {
        timeInMillis = ts
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    internal fun previousLocalDayStart(dayStartMs: Long): Long = Calendar.getInstance().apply {
        timeInMillis = dayStartMs
        add(Calendar.DAY_OF_MONTH, -1)
    }.timeInMillis

    // ── Test hooks ────────────────────────────────────────────────────────

    internal fun invalidateCacheForTest() {
        synchronized(pendingLock) {
            pending.clear()
            pendingTotal = 0
            pendingDayStart = 0L
            pendingSinceUptimeMs = 0L
        }
        store.invalidateCacheForTest()
    }
}
