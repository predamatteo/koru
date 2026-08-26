package com.dev.koru.channels.blocking

import android.app.usage.UsageStatsManager
import android.app.Activity
import android.content.Context
import com.dev.koru.inventory.PackageInventory
import com.dev.koru.inventory.PackageVisibility
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.UsageCounter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: query di usage-stats foreground (totali nella finestra, per-giorno,
 * e il totale "oggi" per singolo package). Estratto da `BlockingMethodChannel`
 * (ARCH-09) coi suoi helper privati.
 *
 * ## Il filtro delle statistiche vive QUI
 *
 * I due endpoint bulk scartano i package che non sono app dell'utente
 * (framework, systemui, servizi, altri launcher, Koru stessa) via
 * [PackageVisibility]. È la frontiera giusta per tre motivi:
 *
 * 1. **Un solo punto per tutto il Dart.** Filtrando qui diventano puliti in un
 *    colpo solo `periodUsageProvider`, `periodScreenTimeMsProvider`,
 *    `previousPeriodScreenTimeMsProvider`, `topAppsByUsageProvider`,
 *    `weeklyTopAppsProvider`, `weeklyDailyUsageProvider`,
 *    `selectedDayUsageProvider` e tutta `statistics_screen.dart`, senza
 *    toccare una riga di Dart.
 * 2. **NON in [UsageCounter].** `UsageCounter.todayForegroundMs` riusa la
 *    stessa mappa ed è il percorso di ENFORCEMENT dei cap giornalieri:
 *    filtrare lì spegnerebbe i limiti sui package filtrati in silenzio, senza
 *    errori e senza test rossi.
 * 3. **`getUsageTodayMs` resta intatto.** È la vista di un cap che l'utente ha
 *    scelto esplicitamente per quel package: filtrarla sarebbe rispondere
 *    "zero" a una domanda legittima.
 *
 * Il widget home non passa da qui (legge `UsageCounter` diretto) e applica lo
 * STESSO predicato in `UsageWidgetDataSource` — è ciò che tiene il totale del
 * widget uguale a quello della schermata Statistiche.
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
                offload(activity, result) { getUsageStats(activity, startMs, endMs) }
            }
            "getUsageStatsByDay" -> {
                val startMs = call.longArg("startMs")
                val endMs = call.longArg("endMs").takeIf { it > 0 }
                    ?: System.currentTimeMillis()
                offload(activity, result) { getUsageStatsByDay(activity, startMs, endMs) }
            }
            "getUsageTodayMs" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                offload(activity, result) {
                    UsageCounter.todayForegroundMs(activity.applicationContext, pkg)
                }
            }
        }
    }

    /**
     * Esegue [work] su un thread di background e consegna il risultato sulla UI
     * thread. Nessuno di questi metodi può restare sul Platform main thread:
     * ciascuno fa una passata di `UsageStatsManager.queryEvents` sull'intera
     * finestra — la stessa che `UsageWidgetDataSource` documenta a 100-300ms e
     * dichiara di non dover MAI chiamare dal main thread — e ora, sul primo
     * accesso dopo la scadenza del TTL, anche una `queryIntentActivities` per
     * il filtro. Prima erano sincroni: il main thread restava fermo per tutta
     * la durata e la UI Flutter aspettava comunque il result del channel.
     *
     * Stesso pattern di `AppInventoryCallHandler.getInstalledApps`.
     */
    private fun offload(
        activity: Activity,
        result: MethodChannel.Result,
        work: () -> Any,
    ) {
        Thread {
            try {
                val data = work()
                activity.runOnUiThread { result.success(data) }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    result.error("USAGE_STATS_ERROR", e.message, null)
                }
            }
        }.start()
    }

    /// Scarta i package che non sono app dell'utente. Vedi la nota di classe
    /// per il perché il filtro stia qui e non in [UsageCounter].
    private fun userFacing(context: Context, usage: Map<String, Long>): Map<String, Long> =
        PackageVisibility.filterUserFacing(
            usage = usage,
            selfPackage = context.packageName,
            launchablePackages = PackageInventory.launchablePackages(context),
            homePackages = PackageInventory.homePackages(context),
            skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
        )

    private fun getUsageStats(context: Context, startMs: Long, endMs: Long): List<Map<String, Any>> {
        val totals = userFacing(context, UsageCounter.foregroundMsPerPackage(context, startMs, endMs))
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
            .map { (dayStart, rawTotals) ->
                val totals = userFacing(context, rawTotals)
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
