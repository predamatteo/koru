package com.dev.koru.strictmode

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.dev.koru.BuildConfig
import com.dev.koru.contract.BlockingContract
import com.dev.koru.diagnostics.BlackBox
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

    /// Cache della mask con TTL breve. `handleEvent` gira sul main thread del
    /// processo del service (MAIN process: l'AndroidManifest NON dichiara
    /// `android:process` per [KoruAccessibilityService]) ed è invocato a OGNI
    /// window-state-change. `StrictModeStore.readMask` NON è O(1): su un record
    /// esistente calcola un HMAC keyed dall'Android Keystore (round-trip IPC)
    /// per la tamper-evidence. Farlo a ogni evento compete col main thread →
    /// jank/ANR ai cambi app. Era stata azzerata (CACHE_MS=0) temendo staleness
    /// cross-process, ma quel timore è infondato: vedi sotto.
    ///
    /// La correttezza NON dipende dal TTL: ogni write path invalida
    /// ESPLICITAMENTE la cache ([StrictModeMethodChannel.setStrictModeOptions]
    /// e `performEmergencyUnblock`, [KoruDeviceAdminReceiver], [StrictModeFailSafe]
    /// → [invalidateCache]). Poiché service e writer condividono lo STESSO
    /// processo, `invalidateCache` azzera esattamente questa cache in-memory:
    /// nessuna staleness cross-process. Il TTL è solo un backstop che limita la
    /// frequenza delle read costose fra una write e l'altra.
    private var cachedMask: Int = -1
    private var lastReadTime = 0L
    private const val CACHE_MS = 1_500L

    /// Soglia oltre la quale una lettura della mask (round-trip Keystore + HMAC)
    /// e' abbastanza lenta da contare come stall del main thread del processo.
    /// `handleEvent` gira sul main thread: una readMask > ~5ms a raffica durante
    /// un burst di window-event e' il meccanismo #1 sospettato del FREEZE. La
    /// scatola nera registra SOLO i MISS oltre questa soglia (≤1/1.5s per via del
    /// TTL, e di norma sub-ms quando la strict mode e' spenta) → segnale pulito.
    private const val KEYSTORE_SLOW_MS = 5L

    private fun getMask(context: Context): Int {
        if (CACHE_MS > 0L) {
            val now = System.currentTimeMillis()
            if (cachedMask >= 0 && now - lastReadTime < CACHE_MS) {
                if (BuildConfig.DEBUG) Log.d("KoruPerf", "getMask HIT (cache, no Keystore)")
                return cachedMask
            }
            if (BuildConfig.DEBUG) Log.d("KoruPerf", "getMask MISS -> readMask (Keystore HMAC)")
            val t0 = System.currentTimeMillis()
            cachedMask = StrictModeStore.readMask(context)
            val dur = System.currentTimeMillis() - t0
            lastReadTime = now
            if (dur >= KEYSTORE_SLOW_MS) {
                BlackBox.log(
                    "MASK",
                    "readMask Keystore/HMAC ${dur}ms mask=$cachedMask — stall sul main thread (burst di window-event = freeze)",
                )
            }
            return cachedMask
        }
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
