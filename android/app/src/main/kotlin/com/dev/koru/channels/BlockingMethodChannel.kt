package com.dev.koru.channels

import android.app.Activity
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import com.dev.koru.notification.NotificationFilterStore
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.BypassCountStore
import com.dev.koru.service.LockForegroundService
import com.dev.koru.service.UsageCounter
import com.dev.koru.strictmode.StrictModeStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/// Dart `int` piccoli (fino a ~2.1B) entrano nel MethodChannel come Integer;
/// valori più grandi (es. timestamps) come Long. `call.argument<Long>` fa
/// un cast runtime che CRASHA se il valore arriva come Integer. Questo
/// helper gestisce entrambi in modo safe.
private fun MethodCall.longArg(name: String): Long = when (val v = argument<Any>(name)) {
    is Long -> v
    is Int -> v.toLong()
    is Number -> v.toLong()
    else -> 0L
}

/// Tollera tre forme che il Dart può inviare per un entry di limite:
///   1. `Number` (legacy): solo i minuti, strict=true di default;
///   2. `Map<String, Any>` con keys `minutes` (Number) + `strict` (Bool);
///   3. qualunque altro tipo → null (ignorato in upstream).
private fun parseLimitEntry(raw: Any?): AppUsageLimitsStore.LimitEntry? = when (raw) {
    is Number -> AppUsageLimitsStore.LimitEntry(
        minutes = raw.toInt(),
        strict = true,
    )
    is Map<*, *> -> {
        val minutes = (raw["minutes"] as? Number)?.toInt() ?: 0
        val strict = raw["strict"] as? Boolean ?: true
        if (minutes > 0) {
            AppUsageLimitsStore.LimitEntry(minutes = minutes, strict = strict)
        } else null
    }
    else -> null
}

object BlockingMethodChannel {
    private const val CHANNEL = "com.koru/blocking"

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBlockingService" -> {
                        try {
                            val intent = Intent(activity, LockForegroundService::class.java).apply {
                                action = LockForegroundService.ACTION_START
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                activity.startForegroundService(intent)
                            } else {
                                activity.startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SERVICE_START_FAILED", e.message, null)
                        }
                    }
                    "stopBlockingService" -> {
                        val intent = Intent(activity, LockForegroundService::class.java).apply {
                            action = LockForegroundService.ACTION_STOP
                        }
                        activity.startService(intent)
                        result.success(true)
                    }
                    "isBlockingServiceRunning" -> result.success(LockForegroundService.isRunning)
                    "getInstalledApps" -> {
                        // Offload su background thread: `getInstalledApps`
                        // scansiona TUTTI i package, chiama
                        // `getApplicationIcon` (decode drawable da APK) e fa
                        // un compress PNG per ciascuno. Su set realistici
                        // (60-150 app) può prendere 1-3s e bloccare il
                        // Platform main thread, freezando la UI Flutter
                        // (che attende il method channel result). Eseguiamo
                        // tutto su Thread() e torniamo alla UI thread solo
                        // per `result.success`/`result.error`.
                        Thread {
                            try {
                                val data = getInstalledApps(activity)
                                activity.runOnUiThread { result.success(data) }
                            } catch (e: Exception) {
                                activity.runOnUiThread {
                                    result.error(
                                        "INSTALLED_APPS_ERROR",
                                        e.message,
                                        null,
                                    )
                                }
                            }
                        }.start()
                    }
                    "getInstalledPackageNames" ->
                        result.success(getInstalledPackageNames(activity))
                    "getLauncherPackageNames" -> {
                        // Set di package che dichiarano un'activity HOME
                        // (sono altri launcher installati: Nova, Pixel
                        // Launcher, ecc.). Esposto separatamente da
                        // `getInstalledApps` per non dover toccare lo schema
                        // di `InstalledAppInfo` lato Dart; il provider Dart
                        // fa il merge.
                        result.success(
                            resolveLauncherPackages(activity.packageManager).toList()
                        )
                    }
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
                    "startQuickBlock" -> {
                        val durationMs = call.longArg("durationMs")
                        val whitelist = (call.argument<List<String>>("whitelist") ?: emptyList())
                            .toSet()
                        // Il context va attaccato anche se il service non è
                        // mai stato istanziato: serve per persistere lo
                        // snapshot letto dal processo :accessibility.
                        LockForegroundService.quickBlockManager.attachContext(activity.applicationContext)
                        LockForegroundService.quickBlockManager.startQuickBlock(
                            durationMs,
                            whitelist,
                        )
                        result.success(true)
                    }
                    "stopQuickBlock" -> {
                        LockForegroundService.quickBlockManager.stop()
                        result.success(true)
                    }
                    "startPomodoro" -> {
                        val workMs = call.longArg("workMs")
                        val breakMs = call.longArg("breakMs")
                        val cycles = call.argument<Int>("cycles") ?: 4
                        val whitelist = (call.argument<List<String>>("whitelist") ?: emptyList())
                            .toSet()
                        LockForegroundService.quickBlockManager.attachContext(activity.applicationContext)
                        LockForegroundService.quickBlockManager.startPomodoro(
                            workMs,
                            breakMs,
                            cycles,
                            whitelist,
                        )
                        result.success(true)
                    }
                    "stopPomodoro" -> {
                        LockForegroundService.quickBlockManager.stop()
                        result.success(true)
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        val intent = activity.packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            activity.startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "uninstallApp" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        // Guard strict mode: se l'utente sta cercando di
                        // disinstallare Koru stessa mentre BLOCK_UNINSTALLING
                        // è attivo, blocchiamo l'intent prima ancora di
                        // arrivare al package installer (defense in depth:
                        // anche se StrictModeEnforcer dovesse missarlo,
                        // questo livello rifiuta).
                        if (pkg == activity.packageName) {
                            val mask = StrictModeStore.readMask(activity)
                            if (mask and StrictModeStore.BLOCK_UNINSTALLING != 0) {
                                result.error(
                                    "BLOCK_UNINSTALLING",
                                    "Cannot uninstall Koru while strict mode protects uninstalling.",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                        }
                        try {
                            val intent = Intent(Intent.ACTION_DELETE).apply {
                                data = android.net.Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNINSTALL_FAILED", e.message, null)
                        }
                    }
                    "openAppInfo" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = android.net.Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("APP_INFO_FAILED", e.message, null)
                        }
                    }
                    "getBatteryLevel" -> {
                        val bm = activity.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                        result.success(bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY))
                    }
                    "isCharging" -> {
                        val bm = activity.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                        result.success(bm.isCharging)
                    }
                    "getDefaultDialerPackage" -> {
                        result.success(resolveDefaultDialer(activity))
                    }
                    "getDefaultCameraPackage" -> {
                        result.success(resolveDefaultCamera(activity))
                    }
                    "getAppDailyLimits" -> {
                        // Schema scambiato col Dart: {pkg: {minutes:Int, strict:Bool}}.
                        // Lo store gestisce backward compat sul disco; qui esponiamo
                        // sempre il formato esteso così il Dart non deve disambiguare.
                        val entries = AppUsageLimitsStore.read(activity.applicationContext)
                        val out = entries.mapValues { (_, v) ->
                            mapOf("minutes" to v.minutes, "strict" to v.strict)
                        }
                        result.success(out)
                    }
                    "setAppDailyLimits" -> {
                        @Suppress("UNCHECKED_CAST")
                        val raw = call.argument<Map<String, Any>>("limits") ?: emptyMap()
                        val parsed = raw.mapNotNull { (pkg, v) ->
                            val entry = parseLimitEntry(v) ?: return@mapNotNull null
                            pkg to entry
                        }.toMap()
                        AppUsageLimitsStore.save(activity.applicationContext, parsed)
                        result.success(true)
                    }
                    "getBypassCountToday" -> {
                        val pkg = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        result.success(
                            BypassCountStore.todayCount(activity.applicationContext, pkg),
                        )
                    }
                    "resetBypassCount" -> {
                        val pkg = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        BypassCountStore.reset(activity.applicationContext, pkg)
                        result.success(true)
                    }
                    "getUsageTodayMs" -> {
                        val pkg = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        result.success(UsageCounter.todayForegroundMs(activity.applicationContext, pkg))
                    }
                    "getSilencedPackages" -> {
                        result.success(
                            NotificationFilterStore.read(activity.applicationContext).toList()
                        )
                    }
                    "setSilencedPackages" -> {
                        val list = call.argument<List<String>>("packages") ?: emptyList()
                        NotificationFilterStore.save(activity.applicationContext, list.toSet())
                        result.success(true)
                    }
                    "isNotificationAccessGranted" -> {
                        val flat = android.provider.Settings.Secure.getString(
                            activity.contentResolver,
                            "enabled_notification_listeners",
                        ) ?: ""
                        val expected = "${activity.packageName}/" +
                            "com.dev.koru.notification.KoruNotificationListenerService"
                        result.success(flat.contains(expected))
                    }
                    "openNotificationAccessSettings" -> {
                        val ok = openNotificationAccessSettings(activity)
                        result.success(ok)
                    }
                    "getCurrentWifiSsid" -> {
                        result.success(getCurrentWifiSsid(activity))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launcherPkgs = resolveLauncherPackages(pm)
        val launchablePkgs = resolveLaunchablePackages(pm)
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            // Solo app con un'activity lanciabile (MAIN + CATEGORY_LAUNCHER),
            // come ogni launcher stock. Il vecchio criterio
            // `FLAG_SYSTEM == 0 || hasLaunchIntent` lasciava passare i
            // componenti Google distribuiti via Play Store (Android System
            // SafetyCore, Key Verifier, ...) e le tastiere/IME: NON sono di
            // sistema (FLAG_SYSTEM == 0) ma non hanno front-door → comparivano
            // nel drawer pur non essendo apribili (tap = niente). Gating per
            // membership nel set launchable li esclude tutti, senza denylist
            // hardcoded da mantenere quando Google ne aggiunge altri.
            .filter { launchablePkgs.contains(it.packageName) }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "label" to (pm.getApplicationLabel(app)?.toString() ?: app.packageName),
                    "icon" to try { drawableToBytes(pm.getApplicationIcon(app)) } catch (_: Exception) { null },
                    "isLauncher" to launcherPkgs.contains(app.packageName),
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    /// Set di package che dichiarano almeno un'activity con
    /// CATEGORY_HOME (cioè sono launcher). Calcolato una volta per
    /// chiamata a `getInstalledApps` e poi usato come lookup O(1) per
    /// taggare il flag `isLauncher` su ciascuna app — il Dart-side
    /// filtra il drawer per nascondere altri launcher (Nova, Pixel
    /// Launcher, ecc.) che altrimenti creavano confusione.
    private fun resolveLauncherPackages(pm: PackageManager): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return try {
            pm.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    /// Set di package che dichiarano almeno un'activity con
    /// CATEGORY_LAUNCHER, cioè sono apribili dal drawer (hanno un'icona
    /// "front-door"). È il criterio di visibilità del drawer Koru: tutto
    /// ciò che non è in questo set — componenti Play come SafetyCore /
    /// Key Verifier, IME/tastiere, servizi di background — non è apribile
    /// e va nascosto. Speculare a [resolveLauncherPackages] ma con
    /// CATEGORY_LAUNCHER al posto di CATEGORY_HOME.
    private fun resolveLaunchablePackages(pm: PackageManager): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return try {
            pm.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    /// Variante "cheap" usata dal lifecycle observer Dart per il diff-based
    /// refresh: ritorna solo i package names launchable, senza label e
    /// senza icone, evitando il decode delle bitmap (operazione costosa
    /// che — se eseguita ad ogni resume — causa un freeze visibile della UI).
    private fun getInstalledPackageNames(context: Context): List<String> {
        val pm = context.packageManager
        // Stesso criterio di [getInstalledApps] — i due endpoint DEVONO
        // ritornare lo stesso set di package: sono fotografie consistenti
        // dello stesso PackageManager (TodayLimitsCard incrocia questa lista
        // col drawer per filtrare le entries fantasma di app disinstallate).
        // Una sola queryIntentActivities invece di N getLaunchIntentForPackage:
        // questo è il path "cheap" invocato a ogni resume.
        val launchablePkgs = resolveLaunchablePackages(pm)
        return pm.getInstalledApplications(0)
            .filter { launchablePkgs.contains(it.packageName) }
            .map { it.packageName }
            .sorted()
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

    /// Apre le Settings di "Notification access" con fallback robusto:
    /// prima prova il deep-link diretto al component di Koru
    /// (ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS, API 30+), poi
    /// la action generica, poi Settings root. Ciascun tentativo è
    /// wrapped in try/catch per evitare crash su device dove l'intent
    /// non è disponibile o è bloccato da policy OEM.
    private fun openNotificationAccessSettings(activity: Activity): Boolean {
        val component = android.content.ComponentName(
            activity.packageName,
            "com.dev.koru.notification.KoruNotificationListenerService",
        )

        // Tentativo 1: deep-link al detail (Android 11+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(
                    android.provider.Settings
                        .ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS,
                )
                    .putExtra(
                        android.provider.Settings
                            .EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        component.flattenToString(),
                    )
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // Tentativo 2: lista generica di notification listeners.
        try {
            val intent = Intent(
                android.provider.Settings
                    .ACTION_NOTIFICATION_LISTENER_SETTINGS,
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}

        // Fallback finale: Settings root.
        try {
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}
        return false
    }

    /// Legge il SSID della rete WiFi corrente. Su Android 10+ richiede
    /// ACCESS_FINE_LOCATION; se permesso non concesso ritorna null o
    /// "<unknown ssid>". L'UI gestisce la degradazione gentilmente.
    private fun getCurrentWifiSsid(context: Context): String? {
        return try {
            val wm = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
            val info = wm?.connectionInfo ?: return null
            val ssid = info.ssid
            if (ssid == null || ssid == "<unknown ssid>") return null
            // SSID è restituito wrapped tra virgolette.
            if (ssid.length >= 2 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid.substring(1, ssid.length - 1)
            } else {
                ssid
            }
        } catch (_: Exception) {
            null
        }
    }

    /// Risolve il package del dialer di sistema (telecom + fallback su
     /// Intent.ACTION_DIAL se TelecomManager non disponibile).
    private fun resolveDefaultDialer(context: Context): String? {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val tm = context.getSystemService(Context.TELECOM_SERVICE)
                    as? android.telecom.TelecomManager
                val pkg = tm?.defaultDialerPackage
                if (!pkg.isNullOrBlank()) return pkg
            }
        } catch (_: Exception) {}
        val intent = Intent(Intent.ACTION_DIAL)
        val ri = context.packageManager.resolveActivity(intent, 0)
        return ri?.activityInfo?.packageName
    }

    /// Risolve l'app fotocamera di default (IMAGE_CAPTURE).
    private fun resolveDefaultCamera(context: Context): String? {
        val intent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)
        val ri = context.packageManager.resolveActivity(intent, 0)
        return ri?.activityInfo?.packageName
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(1),
                drawable.intrinsicHeight.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888
            ).also {
                val canvas = Canvas(it)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        val scaled = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
        return ByteArrayOutputStream()
            .also { scaled.compress(Bitmap.CompressFormat.PNG, 100, it) }
            .toByteArray()
    }
}
