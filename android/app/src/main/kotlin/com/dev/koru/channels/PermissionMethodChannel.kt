package com.dev.koru.channels

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object PermissionMethodChannel {
    private const val CHANNEL = "com.koru/permissions"

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAccessibilityService" -> result.success(isAccessibilityEnabled(activity))
                    "openAccessibilitySettings" -> {
activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "checkUsageStatsPermission" -> result.success(hasUsageStats(activity))
                    "openUsageStatsSettings" -> {
activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(activity))
                    "openOverlaySettings" -> {
activity.startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:${activity.packageName}")
                            )
                        )
                        result.success(null)
                    }
                    "checkBatteryOptimization" -> {
                        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(activity.packageName))
                    }
                    "requestDisableBatteryOptimization" -> {
activity.startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:${activity.packageName}")
                            )
                        )
                        result.success(null)
                    }
                    "checkNotificationListener" -> result.success(isNotificationListenerEnabled(activity))
                    "openNotificationListenerSettings" -> {
openNotificationListenerSettingsSafe(activity)
                        result.success(null)
                    }
                    "isDefaultLauncher" -> result.success(isDefaultLauncher(activity))
                    "openDefaultLauncherSettings" -> {
activity.startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                        result.success(null)
                    }
                    "setLauncherModeEnabled" -> {
                        // MainActivity ora ha HOME filter sempre enabled (no
                        // più activity-alias). Il toggle apre il picker di
                        // sistema per impostare Koru come default launcher.
                        activity.startActivity(
                            Intent(Settings.ACTION_HOME_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    }
                    "isLauncherModeEnabled" -> {
                        // "Enabled" = Koru è effettivamente il default launcher.
                        result.success(isDefaultLauncher(activity))
                    }
                    "setLauncherGestureExclusion" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setLauncherGestureExclusion(activity, enabled)
                        result.success(null)
                    }
                    "checkAllPermissions" -> {
                        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(
                            mapOf(
                                "accessibility" to isAccessibilityEnabled(activity),
                                "usageStats" to hasUsageStats(activity),
                                "overlay" to Settings.canDrawOverlays(activity),
                                "battery" to pm.isIgnoringBatteryOptimizations(activity.packageName),
                                "notificationListener" to isNotificationListenerEnabled(activity),
                                "defaultLauncher" to isDefaultLauncher(activity),
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Override delle gesture di sistema sul launcher (richiesto SOLO mentre
     * [com.dev.koru.MainActivity] mostra la LauncherHomeScreen; il lato Dart la
     * attiva on-mount e la rimuove on-dispose).
     *
     * Quando i telefoni hanno la navigazione a gesture attiva, il sistema
     * intercetta gli swipe dai bordi (sinistro/destro = indietro) prima che
     * arrivino all'app, rendendo inutilizzabili gli swipe personalizzati del
     * launcher. [android.view.View.setSystemGestureExclusionRects] dichiara le
     * zone in cui è l'app a gestire le gesture.
     *
     * Limiti di Android (non aggirabili da un'app):
     * - back gesture (bordi sx/dx): l'esclusione è limitata a 200dp per bordo
     *   (il sistema tiene i 200dp più in basso);
     * - home gesture (dal basso): la striscia mandatory è riservata e NON
     *   escludibile — lo swipe-su funziona solo se parte sopra la pillola.
     *
     * API 29+ (Q): no-op su versioni precedenti (lì la nav a 3 tasti non
     * confligge con gli swipe). Rect impostati via [View.post] perché servono
     * width/height dopo il layout pass.
     */
    private fun setLauncherGestureExclusion(activity: Activity, enabled: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val root = activity.window?.decorView ?: return
        root.post {
            val w = root.width
            val h = root.height
            root.systemGestureExclusionRects = if (enabled && w > 0 && h > 0) {
                listOf(Rect(0, 0, w, h))
            } else {
                emptyList()
            }
        }
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
            .any { it.resolveInfo.serviceInfo.packageName == context.packageName }
    }

    private fun hasUsageStats(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabled.split(":")
            .any { it.startsWith(context.packageName + "/") }
    }

    private fun isDefaultLauncher(context: Context): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val resolve = context.packageManager.resolveActivity(intent, 0)
        return resolve?.activityInfo?.packageName == context.packageName
    }

    /// Apre "Notification access" con 3 fallback progressivi. Su alcuni
    /// OEM (OnePlus/Oppo/ColorOS/MIUI) l'intent generico può non essere
    /// risolvibile e `startActivity` solleva ActivityNotFoundException
    /// che, se non catturata, termina il processo Flutter.
    private fun openNotificationListenerSettingsSafe(activity: Activity) {
        val component = ComponentName(
            activity.packageName,
            "com.dev.koru.notification.KoruNotificationListenerService",
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(
                    Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS,
                )
                    .putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        component.flattenToString(),
                    )
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return
            } catch (_: Exception) {}
        }
        try {
            activity.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            return
        } catch (_: Exception) {}
        try {
            activity.startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (_: Exception) {}
    }
}
