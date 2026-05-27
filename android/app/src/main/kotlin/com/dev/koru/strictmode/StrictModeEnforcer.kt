package com.dev.koru.strictmode

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.dev.koru.contract.BlockingContract
import com.dev.koru.service.KoruAccessibilityService

object StrictModeEnforcer {
    private const val TAG = "StrictModeEnforcer"

    /// Riporta l'utente in Koru via il path "intent diretto", non HOME.
    /// Vedi [KoruAccessibilityService.performGoHomeForBlock] per la
    /// motivazione completa (HOME apriva il launcher di stock e resettava
    /// GoRouter al `/launcher`).
    private fun goHomeSuppressed(service: AccessibilityService) {
        if (service is KoruAccessibilityService) {
            service.performGoHomeForBlock()
        } else {
            KoruAccessibilityService.suppressLauncherNavigationUntilMs =
                System.currentTimeMillis() + 1_500L
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
        }
    }

    // ARCH-06: i bit Strict Mode vivono ora in [BlockingContract] (single
    // source). Questi restano `const val` PUBBLICI come alias per i call site
    // che li importano da qui (es. il riferimento `mask and BLOCK_SETTINGS`
    // sotto resta invariato), evitando un refactor a tappeto. Il valore è
    // quello del contratto: niente più "DEVONO matchare" a mano.
    const val BLOCK_EDITING = BlockingContract.BLOCK_EDITING
    const val BLOCK_SETTINGS = BlockingContract.BLOCK_SETTINGS
    const val BLOCK_UNINSTALLING = BlockingContract.BLOCK_UNINSTALLING
    const val BLOCK_RECENT_APPS = BlockingContract.BLOCK_RECENT_APPS
    const val BLOCK_SPLIT_SCREEN = BlockingContract.BLOCK_SPLIT_SCREEN

    // ARCH-06: set condiviso con KoruAccessibilityService via [BlockingContract].
    private val SETTINGS_PACKAGES = BlockingContract.SETTINGS_PACKAGES

    private val UNINSTALL_PACKAGES = setOf(
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.miui.packageinstaller",
    )

    /// Allowlist BASE: voci di Settings sempre concesse anche con strict mode
    /// attivo, perché necessarie per concedere/revocare permessi richiesti
    /// da Koru stesso (notification listener, usage access, app overlay).
    /// Match è substring case-insensitive sul className.
    private val PERMISSION_ALLOWLIST_BASE = listOf(
        "NotificationAccess",              // notification listener detail + list
        "NotificationListener",
        "UsageAccess",                     // package usage stats
        "AppUsageAccess",
        "ManageAppOverlay",                // draw over other apps
        "AppOverlayPermission",
        "RequestIgnoreBatteryOptimization",
        "IgnoreBatteryOptimization",
    )

    /// Voci sensibili che PRIMA erano in allowlist incondizionata e ora sono
    /// concesse SOLO quando BLOCK_SETTINGS è disabilitato. Razionale:
    /// - `AccessibilityDetails` / `AccessibilityServiceDetail`: l'utente può
    ///   disabilitare il servizio di accessibilità di Koru → bypass totale
    ///   dello strict mode. Va bloccato finché strict è attivo.
    /// - `AccessibilitySettings`: stessa identica esposizione, lista
    ///   completa dei servizi a11y dove Koru può essere disabilitato.
    /// - `HomeSettings`: cambiare il default launcher mentre strict è ON
    ///   permette di nascondere Koru. Resta bloccato.
    /// - `HighPowerApplication`: la pagina di battery optimization permette
    ///   anche di rimuovere Koru dalla whitelist → kill del foreground
    ///   service in background → bypass. Bloccato.
    private val PERMISSION_ALLOWLIST_WHEN_SETTINGS_UNLOCKED = listOf(
        "AccessibilityDetails",
        "AccessibilityServiceDetail",
        "AccessibilitySettings",
        "HomeSettings",
        "HighPowerApplication",
    )

    /// Allowlist effettiva data la mask corrente. Quando BLOCK_SETTINGS è
    /// attivo, eliminiamo le voci sensibili che potrebbero permettere
    /// all'utente di disabilitare Koru indirettamente.
    private fun effectiveAllowlist(mask: Int): List<String> {
        if (mask and BLOCK_SETTINGS == 0) {
            // Strict mode su Settings OFF: l'utente può comunque entrare in
            // Settings, quindi non ha senso filtrare nessuna pagina.
            return PERMISSION_ALLOWLIST_BASE + PERMISSION_ALLOWLIST_WHEN_SETTINGS_UNLOCKED
        }
        return PERMISSION_ALLOWLIST_BASE
    }

    private fun isPermissionGrantPage(className: String, mask: Int): Boolean {
        if (className.isEmpty()) return false
        return effectiveAllowlist(mask).any {
            className.contains(it, ignoreCase = true)
        }
    }

    /// Cache della mask. Era 3 secondi → ridotta a 0 per garantire che
    /// dopo una write da [StrictModeMethodChannel.setStrictModeOptions]
    /// l'enforcer veda subito il nuovo valore, senza affidarsi al call
    /// esplicito di [invalidateCache] su tutti i write path. EncryptedSharedPreferences
    /// fa caching interno comunque, quindi la read è O(1) in memoria.
    private var cachedMask: Int = -1
    private var lastReadTime = 0L
    private const val CACHE_MS = 0L

    private fun getMask(context: Context): Int {
        if (CACHE_MS > 0L) {
            val now = System.currentTimeMillis()
            if (cachedMask >= 0 && now - lastReadTime < CACHE_MS) return cachedMask
            cachedMask = StrictModeStore.readMask(context)
            lastReadTime = now
            return cachedMask
        }
        // Zero-cache path: leggi sempre fresco. La EncryptedSharedPreferences
        // tiene un caching interno per cui questo non è un I/O cost.
        return StrictModeStore.readMask(context)
    }

    fun invalidateCache() {
        cachedMask = -1
        lastReadTime = 0L
    }

    fun handleEvent(service: AccessibilityService, event: AccessibilityEvent): Boolean {
        val mask = getMask(service.applicationContext)
        if (mask == 0) return false

        val packageName = event.packageName?.toString() ?: return false
        val className = event.className?.toString() ?: ""

        if (mask and BLOCK_SETTINGS != 0 && SETTINGS_PACKAGES.contains(packageName)) {
            if (isPermissionGrantPage(className, mask)) {
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
