package com.dev.koru.service

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Calendar

/**
 * Tempo in foreground per-package calcolato con state machine su
 * `queryEvents` (RESUMED / PAUSED / STOPPED). Condiviso tra il main
 * process (UI via [com.dev.koru.channels.BlockingMethodChannel]) e il
 * processo `:accessibility` ([KoruAccessibilityService]) per garantire
 * che la barra "used / cap" mostrata all'utente e la decisione di
 * blocco leggano lo stesso numero.
 *
 * Storia: il channel usava già questo algoritmo dopo aver osservato
 * sotto-conteggi con `queryUsageStats().totalTimeInForeground`, ma il
 * service di blocco era rimasto sul vecchio path e scattava il daily
 * limit molto prima del valore mostrato nella card.
 *
 * Perché NON `queryUsageStats().totalTimeInForeground`:
 * - Overlay/PiP/notifiche di Instagram/TikTok NON generano sempre
 *   MOVE_TO_BACKGROUND → il counter di Android si gonfia e non torna
 *   indietro, bloccando l'app prima del tempo.
 * - `queryUsageStats(INTERVAL_DAILY)` può restituire più bucket per
 *   lo stesso giorno dopo reboot/cambio timezone → double-count.
 * - `totalTimeInForeground` riflette il bucket intero, non la finestra.
 */
object UsageCounter {

    /** Minuti dall'inizio del giorno locale per `packageName`, in ms. */
    fun todayForegroundMs(context: Context, packageName: String): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val from = cal.timeInMillis
        val now = System.currentTimeMillis()
        return try {
            foregroundMsPerPackage(context, from, now)[packageName] ?: 0L
        } catch (_: Exception) { 0L }
    }

    /**
     * Esegue la state machine su `queryEvents` per la finestra
     * [startMs, endMs] e invoca [onSession] per ogni sessione di foreground
     * con `(packageName, fromTs, toTs)` RAW (non clippati né splittati): è il
     * chiamante a decidere come accumulare (totale piatto vs per-giorno).
     *
     * Condiviso tra [foregroundMsPerPackage] e [foregroundMsPerPackagePerDay]
     * così le due viste non possono divergere su come una sessione viene
     * riconosciuta.
     *
     * Algoritmo portato da minimalist_phone (decompiled: a.java:323-397):
     *
     * 1. **Sort globale per timestamp**: `queryEvents()` NON garantisce
     *    l'ordine stretto dei ts sugli OEM customizzati (MIUI, ColorOS,
     *    One UI). Eventi fuori ordine causano pairing sbagliato.
     *
     * 2. **State machine globale, non per-pkg**: una sola app può essere
     *    in foreground su Android → quando un pkg diverso fa RESUMED,
     *    la sessione aperta di altri pkg DEVE chiudere con quel ts.
     *    Processare pkg-per-pkg lascia sessioni "aperte" per app con
     *    foreground service (Trade Republic, Spotify, GPS) che non
     *    emettono MOVE_TO_BACKGROUND all'uscita.
     *
     * 3. **STOPPED come fallback**: non chiude la sessione direttamente,
     *    perché spesso arriva dell'Activity PRECEDENTE dopo un nuovo
     *    RESUMED (Chrome tabs, splash, ads). Lo salviamo e lo usiamo
     *    come boundary solo se la finestra si chiude senza altri eventi.
     */
    private fun forEachForegroundSession(
        context: Context,
        startMs: Long,
        endMs: Long,
        onSession: (pkg: String, fromTs: Long, toTs: Long) -> Unit,
    ) {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return
        // Query da 24h prima per catturare sessioni ancora aperte all'inizio
        // della finestra. Lo span viene clippato dal chiamante.
        val queryStart = startMs - 24L * 60 * 60 * 1000
        val events = try {
            usm.queryEvents(queryStart, endMs)
        } catch (_: Exception) { return }

        data class Ev(val ts: Long, val type: Int, val pkg: String)
        val all = ArrayList<Ev>()
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            val type = ev.eventType
            if (type != UsageEvents.Event.MOVE_TO_FOREGROUND &&
                type != UsageEvents.Event.MOVE_TO_BACKGROUND &&
                type != 23
            ) continue
            all.add(Ev(ev.timeStamp, type, pkg))
        }
        all.sortBy { it.ts }

        val now = System.currentTimeMillis()
        val windowClose = minOf(endMs, now)

        var currentPkg: String? = null
        var currentStart = 0L
        val lastStopped = HashMap<String, Long>()

        fun closeCurrent(closeTs: Long) {
            val pkg = currentPkg ?: return
            if (closeTs > currentStart) onSession(pkg, currentStart, closeTs)
            currentPkg = null
            currentStart = 0L
        }

        for (e in all) {
            when (e.type) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (currentPkg != null && currentPkg != e.pkg) {
                        val prev = currentPkg!!
                        val stopped = lastStopped[prev] ?: 0L
                        val closeAt = if (stopped in (currentStart + 1)..e.ts) stopped else e.ts
                        closeCurrent(closeAt)
                    } else if (currentPkg == e.pkg) {
                        continue
                    }
                    if (currentPkg == null) {
                        currentPkg = e.pkg
                        currentStart = e.ts
                    }
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (currentPkg == e.pkg) {
                        closeCurrent(e.ts)
                    }
                }
                23 -> {
                    lastStopped[e.pkg] = e.ts
                }
            }
        }

        if (currentPkg != null) {
            val pkg = currentPkg!!
            val stopped = lastStopped[pkg] ?: 0L
            val closeAt = if (stopped > currentStart) stopped else windowClose
            closeCurrent(closeAt)
        }
    }

    /**
     * Tempo in foreground (ms) per package nella finestra [startMs, endMs].
     */
    fun foregroundMsPerPackage(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val totals = HashMap<String, Long>()
        forEachForegroundSession(context, startMs, endMs) { pkg, from, to ->
            val span = clippedSpan(from, to, startMs, endMs)
            if (span > 0) totals[pkg] = (totals[pkg] ?: 0L) + span
        }
        return totals
    }

    /**
     * Come [foregroundMsPerPackage] ma con i totali divisi per giorno locale:
     * `Map<dayStartMs, Map<package, ms>>`, dove `dayStartMs` è la mezzanotte
     * locale del giorno. Le sessioni a cavallo della mezzanotte vengono
     * spezzate e attribuite a ciascun giorno. I giorni senza utilizzo non
     * compaiono nella mappa (il chiamante riempie gli zeri se serve).
     *
     * Usato dalla vista "settimana" delle statistiche per il breakdown
     * per-app del singolo giorno: una sola passata di `queryEvents` copre
     * tutta la finestra.
     */
    fun foregroundMsPerPackagePerDay(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<Long, Map<String, Long>> {
        val buckets = HashMap<Long, HashMap<String, Long>>()
        forEachForegroundSession(context, startMs, endMs) { pkg, from, to ->
            val s = maxOf(from, startMs)
            val e = minOf(to, endMs)
            if (e <= s) return@forEachForegroundSession
            for ((dayStart, ms) in splitByLocalDay(s, e)) {
                if (ms <= 0) continue
                val day = buckets.getOrPut(dayStart) { HashMap() }
                day[pkg] = (day[pkg] ?: 0L) + ms
            }
        }
        return buckets
    }

    /**
     * Divide [fromTs, toTs] in segmenti `(dayStartMs, ms)` allineati alla
     * mezzanotte locale. Robusto al DST: i confini sono calcolati con
     * [Calendar] (non con un offset fisso di 24h). Ritorna lista vuota se
     * la finestra è degenere.
     */
    internal fun splitByLocalDay(fromTs: Long, toTs: Long): List<Pair<Long, Long>> {
        if (toTs <= fromTs) return emptyList()
        val out = ArrayList<Pair<Long, Long>>()
        var s = fromTs
        while (s < toTs) {
            val dayStart = localDayStart(s)
            val nextDay = nextLocalDayStart(dayStart)
            val segEnd = minOf(toTs, nextDay)
            out.add(dayStart to (segEnd - s))
            s = segEnd
        }
        return out
    }

    private fun localDayStart(ts: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = ts
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return cal.timeInMillis
    }

    private fun nextLocalDayStart(dayStartMs: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = dayStartMs
            add(Calendar.DAY_OF_MONTH, 1)
        }
        return cal.timeInMillis
    }

    private fun clippedSpan(
        from: Long,
        to: Long,
        windowStart: Long,
        windowEnd: Long,
    ): Long {
        val s = maxOf(from, windowStart)
        val e = minOf(to, windowEnd)
        return (e - s).coerceAtLeast(0)
    }
}
