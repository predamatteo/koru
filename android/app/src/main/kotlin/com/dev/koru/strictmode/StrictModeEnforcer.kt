package com.dev.koru.strictmode

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.dev.koru.service.KoruAccessibilityService

object StrictModeEnforcer {
    private const val TAG = "StrictModeEnforcer"

    /// Esegue HOME marcando la finestra di soppressione di MainActivity
    /// per non far reset-are GoRouter al `/launcher` (il blocking strict
    /// mode e' per sua natura involontario rispetto alla navigazione
    /// utente, cosi' come APP_BLOCKED). Vedi
    /// [KoruAccessibilityService.suppressLauncherNavigationUntilMs].
    private fun goHomeSuppressed(service: AccessibilityService) {
        KoruAccessibilityService.suppressLauncherNavigationUntilMs =
            System.currentTimeMillis() + 1_500L
        service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
    }

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

    /// Activity di Settings considerate "permission grant pages": il
     /// blocco BLOCK_SETTINGS le lascia passare anche con strict mode on,
     /// così l'utente può concedere i permessi richiesti da Koru (notif
     /// listener, accessibility, usage stats, overlay, battery opt,
     /// default launcher). Match è substring case-insensitive sul className
     /// dell'activity per funzionare cross-OEM.
    private val SETTINGS_PERMISSION_ALLOWLIST = listOf(
        "NotificationAccess",              // notification listener detail + list
        "NotificationListener",
        "AccessibilityDetails",            // enable specific accessibility service
        "AccessibilityServiceDetail",
        "UsageAccess",                     // package usage stats
        "AppUsageAccess",
        "ManageAppOverlay",                // draw over other apps
        "AppOverlayPermission",
        "HighPowerApplication",            // battery optimization whitelist
        "RequestIgnoreBatteryOptimization",
        "IgnoreBatteryOptimization",
        "HomeSettings",                    // default launcher picker
    )

    private fun isPermissionGrantPage(className: String): Boolean {
        if (className.isEmpty()) return false
        return SETTINGS_PERMISSION_ALLOWLIST.any {
            className.contains(it, ignoreCase = true)
        }
    }

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
            if (isPermissionGrantPage(className)) {
                Log.d(TAG, "STRICT: allowlisted permission page $className")
                return false
            }
            Log.w(TAG, "STRICT: Blocked settings: $packageName/$className")
            goHomeSuppressed(service)
            return true
        }

        if (mask and BLOCK_RECENT_APPS != 0) {
            // Check SOLO su className: il bare match su com.android.systemui
            // triggerava sul pull-down della notification shade / QS panel
            // (che hanno package systemui ma NON sono Recents).
            val isRecents = className.contains("Recents", ignoreCase = true) ||
                className.contains("RecentTask", ignoreCase = true) ||
                className.contains("OverviewPanel", ignoreCase = true) ||
                (packageName.contains("launcher", ignoreCase = true) &&
                    className.contains("Recent", ignoreCase = true))
            if (isRecents) {
                Log.w(TAG, "STRICT: Blocked recents: $packageName/$className")
                goHomeSuppressed(service)
                return true
            }
        }

        if (mask and BLOCK_UNINSTALLING != 0) {
            if (UNINSTALL_PACKAGES.contains(packageName) ||
                className.contains("Uninstall", ignoreCase = true) ||
                className.contains("DeleteApp", ignoreCase = true)
            ) {
                Log.w(TAG, "STRICT: Blocked uninstall: $packageName/$className")
                goHomeSuppressed(service)
                return true
            }
        }

        if (mask and BLOCK_SPLIT_SCREEN != 0) {
            if (className.contains("SplitScreen", ignoreCase = true) ||
                className.contains("MultiWindow", ignoreCase = true)
            ) {
                Log.w(TAG, "STRICT: Blocked split screen")
                goHomeSuppressed(service)
                return true
            }
        }

        if (mask and BLOCK_EDITING != 0) {
            if (packageName == "com.android.settings" &&
                (className.contains("InstalledApp", ignoreCase = true) ||
                    className.contains("AppInfo", ignoreCase = true))
            ) {
                Log.w(TAG, "STRICT: Blocked app editing")
                goHomeSuppressed(service)
                return true
            }
        }

        return false
    }
}
