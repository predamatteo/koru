package com.dev.koru.channels

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
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
                        activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "isDefaultLauncher" -> result.success(isDefaultLauncher(activity))
                    "openDefaultLauncherSettings" -> {
                        activity.startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                        result.success(null)
                    }
                    "setLauncherModeEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val pm = activity.packageManager
                        val alias = ComponentName(activity, "com.dev.koru.MainActivityHome")
                        val newState = if (enabled) {
                            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        } else {
                            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                        }
                        pm.setComponentEnabledSetting(
                            alias,
                            newState,
                            android.content.pm.PackageManager.DONT_KILL_APP,
                        )
                        result.success(true)
                    }
                    "isLauncherModeEnabled" -> {
                        val pm = activity.packageManager
                        val alias = ComponentName(activity, "com.dev.koru.MainActivityHome")
                        val state = pm.getComponentEnabledSetting(alias)
                        result.success(
                            state == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        )
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
}
