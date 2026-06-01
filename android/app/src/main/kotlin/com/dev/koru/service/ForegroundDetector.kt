package com.dev.koru.service

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

data class AppsDTO(
    val primaryPackage: String?,
    val secondaryPackage: String?,
    val primaryClassName: String? = null,
    val secondaryClassName: String? = null,
) {
    fun isPackage(pkg: String): Boolean = primaryPackage == pkg || secondaryPackage == pkg
}

object ForegroundDetector {
    /// Lookback di default: 30s e' sufficiente per il polling loop di
    /// LockRunnable (tick ogni 2-5s). Espandere a 1h e' utile solo al
    /// primo boot quando l'evento RESUMED dell'app corrente potrebbe
    /// essere stato emesso molto prima dell'inizio del polling.
    private const val DEFAULT_LOOKBACK_MS = 30_000L
    private const val FALLBACK_LOOKBACK_MS = 3_600_000L
    private const val SPLIT_SCREEN_DEBOUNCE_MS = 50L

    fun detect(context: Context, lookbackMs: Long = DEFAULT_LOOKBACK_MS): AppsDTO? {
        val result = detectInternal(context, lookbackMs)
        if (result != null) return result
        // Fallback boot-time: se il lookback richiesto e' inferiore a 1h e
        // non abbiamo trovato niente, retry con finestra estesa. Risolve il
        // caso "primo blocco dopo reboot" dove l'evento RESUMED dell'app in
        // foreground e' stato emesso minuti fa.
        if (lookbackMs < FALLBACK_LOOKBACK_MS) {
            return detectInternal(context, FALLBACK_LOOKBACK_MS)
        }
        return null
    }

    private fun detectInternal(context: Context, lookbackMs: Long): AppsDTO? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - lookbackMs, now) ?: return null
        val event = UsageEvents.Event()

        var primaryPkg: String? = null
        var secondaryPkg: String? = null
        var primaryClass: String? = null
        var secondaryClass: String? = null
        var lastTimestamp = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    val timeDiff = event.timeStamp - lastTimestamp
                    if (timeDiff >= SPLIT_SCREEN_DEBOUNCE_MS) {
                        secondaryPkg = null
                        secondaryClass = null
                    } else {
                        secondaryPkg = primaryPkg
                        secondaryClass = primaryClass
                    }
                    primaryPkg = event.packageName
                    primaryClass = event.className
                    lastTimestamp = event.timeStamp
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> { /* no-op */ }
            }
        }

        return if (primaryPkg != null) AppsDTO(primaryPkg, secondaryPkg, primaryClass, secondaryClass) else null
    }

    /// Il package che era in foreground IMMEDIATAMENTE PRIMA che [pkg] diventasse
    /// foreground, guardando indietro [lookbackMs]. Serve a distinguere
    /// "app aperta da un link / da un'altra app" (predecessore = un'app reale)
    /// da "aperta dall'icona del launcher" (predecessore = il launcher/home, che
    /// è SEMPRE il foreground immediatamente precedente quando tocchi un'icona).
    ///
    /// Usa UsageStats, NON gli AccessibilityEvent: questi ultimi sono filtrati
    /// dal watched-set dinamico ([KoruAccessibilityService.applyDynamicPackageFilter]),
    /// quindi un'app sorgente non bloccata (es. WhatsApp) non comparirebbe in
    /// `lastForegroundPackage`. UsageStats vede invece tutte le transizioni.
    ///
    /// LAG-ROBUST: l'AccessibilityEvent di apertura di [pkg] può arrivare PRIMA
    /// che UsageStats registri il suo `ACTIVITY_RESUMED`. Quindi non assumiamo
    /// che il resume di [pkg] sia già nel log: prendiamo l'ULTIMO package != [pkg]
    /// visto (= chi stava davanti subito prima), sia che il resume di [pkg] sia
    /// già loggato sia che non lo sia ancora. I resume consecutivi dello stesso
    /// package non spostano il predecessore (filtro `p != current`).
    ///
    /// Ritorna `null` se non determinabile (nessun evento, permesso revocato,
    /// boot prematuro, oppure [pkg] è l'unico foreground recente). Restituiamo il
    /// predecessore "grezzo" (incluso il launcher) di proposito: è il caller a
    /// possedere la lista degli skip-package per la classificazione (launcher/self
    /// → apertura diretta; app reale → apertura da link/altra app).
    fun previousForegroundPackage(
        context: Context,
        pkg: String,
        lookbackMs: Long = 15_000L,
    ): String? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - lookbackMs, now) ?: return null
        val event = UsageEvents.Event()
        // `current` = ultimo package risolto come foreground (in ordine
        // cronologico); `prev` = quello immediatamente precedente, aggiornato
        // SOLO ai cambi reali di package (`p != current`).
        var current: String? = null
        var prev: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                val p = event.packageName ?: continue
                if (p != current) {
                    prev = current
                    current = p
                }
            }
        }
        // Se il resume di [pkg] è già loggato è `current` → il predecessore è
        // `prev`. Se NON è ancora loggato (lag), `current` è ancora chi stava
        // davanti = il predecessore. In entrambi i casi vogliamo "l'ultimo
        // foreground diverso da pkg".
        return if (current == pkg) prev else current
    }
}
