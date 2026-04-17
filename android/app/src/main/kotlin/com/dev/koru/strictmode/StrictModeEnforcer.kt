package com.dev.koru.strictmode

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent

object StrictModeEnforcer {
    private const val TAG = "StrictModeEnforcer"

    const val BLOCK_EDITING = 1
    const val BLOCK_SETTINGS = 2
    const val BLOCK_UNINSTALLING = 4
    const val BLOCK_RECENT_APPS = 8
    const val BLOCK_SPLIT_SCREEN = 16

    private val SETTINGS_PACKAGES = setOf(
        "com.android.settings",
        "com.samsung.android.app.routines",
        "com.miui.securitycenter",
        "com.coloros.safecenter",
        "com.coloros.oplusphonemanager",
        "com.huawei.systemmanager",
        "com.oneplus.security",
        "com.oplus.settings",
    )

    private val UNINSTALL_PACKAGES = setOf(
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.miui.packageinstaller",
    )

    private var cachedMask: Int = -1
    private var lastReadTime = 0L
    private const val CACHE_MS = 3_000L

    private fun getMask(context: Context): Int {
        val now = System.currentTimeMillis()
        if (cachedMask >= 0 && now - lastReadTime < CACHE_MS) return cachedMask
        cachedMask = StrictModeStore.readMask(context)
        lastReadTime = now
        return cachedMask
    }

    fun invalidateCache() { cachedMask = -1 }

    fun handleEvent(service: AccessibilityService, event: AccessibilityEvent): Boolean {
        val mask = getMask(service.applicationContext)
        if (mask == 0) return false

        val packageName = event.packageName?.toString() ?: return false
        val className = event.className?.toString() ?: ""

        if (mask and BLOCK_SETTINGS != 0 && SETTINGS_PACKAGES.contains(packageName)) {
            Log.w(TAG, "STRICT: Blocked settings: $packageName")
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
            return true
        }

        if (mask and BLOCK_RECENT_APPS != 0) {
            val isRecents = packageName == "com.android.systemui" ||
                className.contains("Recents", ignoreCase = true) ||
                className.contains("RecentTask", ignoreCase = true) ||
                (packageName.contains("launcher", ignoreCase = true) &&
                    className.contains("Recent", ignoreCase = true))
            if (isRecents) {
                Log.w(TAG, "STRICT: Blocked recents: $packageName/$className")
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                return true
            }
        }

        if (mask and BLOCK_UNINSTALLING != 0) {
            if (UNINSTALL_PACKAGES.contains(packageName) ||
                className.contains("Uninstall", ignoreCase = true) ||
                className.contains("DeleteApp", ignoreCase = true)
            ) {
                Log.w(TAG, "STRICT: Blocked uninstall: $packageName/$className")
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                return true
            }
        }

        if (mask and BLOCK_SPLIT_SCREEN != 0) {
            if (className.contains("SplitScreen", ignoreCase = true) ||
                className.contains("MultiWindow", ignoreCase = true)
            ) {
                Log.w(TAG, "STRICT: Blocked split screen")
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                return true
            }
        }

        if (mask and BLOCK_EDITING != 0) {
            if (packageName == "com.android.settings" &&
                (className.contains("InstalledApp", ignoreCase = true) ||
                    className.contains("AppInfo", ignoreCase = true))
            ) {
                Log.w(TAG, "STRICT: Blocked app editing")
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                return true
            }
        }

        return false
    }
}
