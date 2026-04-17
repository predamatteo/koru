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
    private const val WINDOW_MS = 3_600_000L // 1h di lookback
    private const val SPLIT_SCREEN_DEBOUNCE_MS = 50L

    fun detect(context: Context): AppsDTO? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - WINDOW_MS, now) ?: return null
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
