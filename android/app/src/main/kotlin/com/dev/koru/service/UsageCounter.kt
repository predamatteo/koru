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
     * Calcola il tempo in foreground (ms) per ogni package nella finestra
     * [startMs, endMs] usando una state machine su `queryEvents`.
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
    fun foregroundMsPerPackage(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return emptyMap()
        // Query da 24h prima per catturare sessioni ancora aperte all'inizio
        // della finestra. Lo span viene clippato a [startMs, endMs].
        val queryStart = startMs - 24L * 60 * 60 * 1000
        val events = try {
            usm.queryEvents(queryStart, endMs)
        } catch (_: Exception) { return emptyMap() }

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

        val totals = HashMap<String, Long>()
        val now = System.currentTimeMillis()
        val windowClose = minOf(endMs, now)

        var currentPkg: String? = null
        var currentStart = 0L
        val lastStopped = HashMap<String, Long>()

        fun closeCurrent(closeTs: Long) {
            val pkg = currentPkg ?: return
            if (closeTs > currentStart) {
                val span = clippedSpan(currentStart, closeTs, startMs, endMs)
                if (span > 0) totals[pkg] = (totals[pkg] ?: 0L) + span
            }
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

        return totals
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
