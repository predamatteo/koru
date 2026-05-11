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
}
