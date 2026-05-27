package com.dev.koru.channels.blocking

import android.app.usage.UsageStatsManager
import android.app.Activity
import android.content.Context
import com.dev.koru.service.UsageCounter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: query di usage-stats foreground (totali nella finestra, per-giorno,
 * e il totale "oggi" per singolo package). Estratto da `BlockingMethodChannel`
 * (ARCH-09) coi suoi helper privati; comportamento e wire-contract invariati.
 */
internal object UsageStatsCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "getUsageStats",
        "getUsageStatsByDay",
        "getUsageTodayMs",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getUsageStats" -> {
                val startMs = call.longArg("startMs")
                val endMs = call.longArg("endMs").takeIf { it > 0 }
                    ?: System.currentTimeMillis()
                result.success(getUsageStats(activity, startMs, endMs))
            }
            "getUsageStatsByDay" -> {
                val startMs = call.longArg("startMs")
                val endMs = call.longArg("endMs").takeIf { it > 0 }
                    ?: System.currentTimeMillis()
                result.success(getUsageStatsByDay(activity, startMs, endMs))
            }
            "getUsageTodayMs" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                result.success(UsageCounter.todayForegroundMs(activity.applicationContext, pkg))
            }
        }
    }

    private fun getUsageStats(context: Context, startMs: Long, endMs: Long): List<Map<String, Any>> {
        val totals = UsageCounter.foregroundMsPerPackage(context, startMs, endMs)
        val lastUsed = queryLastTimeUsedPerPackage(context, startMs, endMs)
        return totals.entries
            .filter { it.value > 0 }
            .map { (pkg, ms) ->
                mapOf(
                    "packageName" to pkg,
                    "totalTimeMs" to ms,
                    "lastTimeUsed" to (lastUsed[pkg] ?: 0L),
                )
            }
    }

    /// Come [getUsageStats] ma diviso per giorno locale: una lista di
    /// `{ dayStartMs, apps: [{ packageName, totalTimeMs }] }`, un entry per
    /// giorno con utilizzo, ordinata per `dayStartMs` crescente e con le app
    /// di ciascun giorno ordinate per tempo desc. Una sola passata di
    /// `queryEvents` copre tutta la finestra (vedi
    /// [UsageCounter.foregroundMsPerPackagePerDay]).
    private fun getUsageStatsByDay(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): List<Map<String, Any>> {
        val perDay = UsageCounter.foregroundMsPerPackagePerDay(context, startMs, endMs)
        return perDay.entries
            .sortedBy { it.key }
            .map { (dayStart, totals) ->
                mapOf(
                    "dayStartMs" to dayStart,
                    "apps" to totals.entries
                        .filter { it.value > 0 }
                        .sortedByDescending { it.value }
                        .map { (pkg, ms) ->
                            mapOf("packageName" to pkg, "totalTimeMs" to ms)
                        },
                )
            }
    }

    /// Ultima volta in cui ciascun package è stato visto come evento
    /// RESUMED/PAUSED nella finestra. Usato per l'UI "lastTimeUsed".
    private fun queryLastTimeUsedPerPackage(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return emptyMap()
        return try {
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
                .groupBy { it.packageName }
                .mapValues { (_, list) -> list.maxOf { it.lastTimeUsed } }
        } catch (_: Exception) { emptyMap() }
    }
}
