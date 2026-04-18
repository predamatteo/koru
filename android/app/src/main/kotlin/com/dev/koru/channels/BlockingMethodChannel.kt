package com.dev.koru.channels

import android.app.Activity
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import com.dev.koru.notification.NotificationFilterStore
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.LockForegroundService
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
                    "getInstalledApps" -> result.success(getInstalledApps(activity))
                    "getUsageStats" -> {
                        val startMs = call.longArg("startMs")
                        val endMs = call.longArg("endMs").takeIf { it > 0 }
                            ?: System.currentTimeMillis()
                        result.success(getUsageStats(activity, startMs, endMs))
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
                        result.success(AppUsageLimitsStore.read(activity.applicationContext))
                    }
                    "setAppDailyLimits" -> {
                        @Suppress("UNCHECKED_CAST")
                        val raw = call.argument<Map<String, Any>>("limits") ?: emptyMap()
                        val parsed = raw.mapValues { (it.value as? Number)?.toInt() ?: 0 }
                        AppUsageLimitsStore.save(activity.applicationContext, parsed)
                        result.success(true)
                    }
                    "getUsageTodayMs" -> {
                        val pkg = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        result.success(getTodayForegroundMs(activity, pkg))
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
                        val intent = Intent(
                            android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(intent)
                        result.success(true)
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
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter {
                it.flags and ApplicationInfo.FLAG_SYSTEM == 0 ||
                    pm.getLaunchIntentForPackage(it.packageName) != null
            }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "label" to (pm.getApplicationLabel(app)?.toString() ?: app.packageName),
                    "icon" to try { drawableToBytes(pm.getApplicationIcon(app)) } catch (_: Exception) { null },
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun getUsageStats(context: Context, startMs: Long, endMs: Long): List<Map<String, Any>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()
        return usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
            .filter { it.totalTimeInForeground > 0 }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "totalTimeMs" to it.totalTimeInForeground,
                    "lastTimeUsed" to it.lastTimeUsed,
                )
            }
    }

    /// Tempo oggi in foreground per `pkg` (dalla mezzanotte locale).
    private fun getTodayForegroundMs(context: Context, pkg: String): Long {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return 0L
        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val from = cal.timeInMillis
        val now = System.currentTimeMillis()
        return try {
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, from, now)
                .filter { it.packageName == pkg }
                .sumOf { it.totalTimeInForeground }
        } catch (_: Exception) { 0L }
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
