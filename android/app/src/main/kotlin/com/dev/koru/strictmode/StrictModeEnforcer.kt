package com.dev.koru.strictmode

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.dev.koru.contract.BlockingContract
import com.dev.koru.diagnostics.BlackBox
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.RecentsDetector
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

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

    /// Cache della mask servita SEMPRE dalla memoria sul main thread.
    /// `handleEvent` gira sul main thread del processo del service (MAIN
    /// process: l'AndroidManifest NON dichiara `android:process` per
    /// [KoruAccessibilityService]) ed è invocato a OGNI window-state-change.
    /// `StrictModeStore.readMask` NON è O(1): su un record esistente calcola un
    /// HMAC keyed dall'Android Keystore (round-trip IPC) per la tamper-evidence.
    /// Farlo SINCRONO a ogni MISS bloccava il main thread (stall 17-1695ms nei
    /// black-box log = freeze ai cambi app). Ora il refresh è ASINCRONO: alla
    /// scadenza del TTL si lancia una read off-main e nel frattempo si continua a
    /// servire l'ultimo valore noto. Il main thread non tocca mai il Keystore.
    ///
    /// La correttezza NON dipende dal TTL: ogni write path invalida
    /// ESPLICITAMENTE la cache ([StrictModeMethodChannel.setStrictModeOptions]
    /// e `performEmergencyUnblock`, [KoruDeviceAdminReceiver], [StrictModeFailSafe]
    /// → [invalidateCache], che fa un re-read SINCRONO immediato). [version]
    /// annulla qualsiasi refresh async in volo che leggeva il valore vecchio,
    /// così un async lento non può sovrascrivere il valore appena invalidato.
    @Volatile private var cachedMask: Int = -1
    @Volatile private var lastReadTime = 0L
    @Volatile private var version = 0
    @Volatile private var appContextRef: Context? = null
    private const val CACHE_MS = 1_500L

    /// Coalescing: in un burst di window-event tutti vedono la cache stale; il
    /// primo schedula il refresh, gli altri trovano `true` e ritornano subito.
    private val refreshing = AtomicBoolean(false)

    /// Executor dedicato (single-thread, daemon) per la read off-main: serializza
    /// i refresh e non trattiene il processo allo shutdown.
    private val refreshExecutor by lazy {
        Executors.newSingleThreadExecutor { r ->
            Thread(r, "koru-strictmask").apply { isDaemon = true }
        }
    }

    /// Soglia oltre la quale una lettura della mask (round-trip Keystore + HMAC)
    /// e' abbastanza lenta da contare come stall (ora misurato sul thread di
    /// background, non più sul main). La scatola nera registra SOLO le read oltre
    /// questa soglia → segnale pulito.
    private const val KEYSTORE_SLOW_MS = 5L

    /// Prime della cache (chiamato da [KoruAccessibilityService.onServiceConnected]):
    /// la prima readMask costosa avviene off-main al connect del service, PRIMA
    /// che l'utente cambi app, così `getMask` trova già un valore e non deve mai
    /// ricadere sul fail-secure durante l'uso normale.
    fun prime(context: Context) {
        appContextRef = context.applicationContext
        scheduleRefresh()
    }

    private fun getMask(context: Context): Int {
        appContextRef = context.applicationContext
        val cached = cachedMask
        if (cached < 0 || System.currentTimeMillis() - lastReadTime >= CACHE_MS) {
            scheduleRefresh()
        }
        // Mai bloccare il main thread: se la prima read non è ancora completata
        // ritorna fail-secure (ALL) finché l'async refresh non popola la cache.
        // Finestra minima e solo al boot del processo (post-prime di norma già
        // popolata); coerente col fail-secure di [StrictModeStore.readMask].
        return if (cached >= 0) cached else BlockingContract.ALL_OPTIONS_ENABLED
    }

    /// Lancia (al più uno alla volta) un refresh off-main della cache. Cattura la
    /// [version] all'avvio e committa il risultato SOLO se non è cambiata nel
    /// frattempo (nessun [invalidateCache] intercorso) → niente stale-write.
    private fun scheduleRefresh() {
        val ctx = appContextRef ?: return
        if (!refreshing.compareAndSet(false, true)) return
        val startVersion = version
        try {
            refreshExecutor.execute {
                try {
                    val t0 = System.currentTimeMillis()
                    val mask = StrictModeStore.readMask(ctx)
                    val dur = System.currentTimeMillis() - t0
                    if (version == startVersion) {
                        cachedMask = mask
                        lastReadTime = System.currentTimeMillis()
                    }
                    if (dur >= KEYSTORE_SLOW_MS) {
                        BlackBox.log(
                            "MASK",
                            "readMask Keystore/HMAC ${dur}ms mask=$mask thread=${Thread.currentThread().name} (off-main async refresh)",
                        )
                    }
                } finally {
                    refreshing.set(false)
                }
            }
        } catch (e: Throwable) {
            refreshing.set(false)
            Log.w(TAG, "strict-mask refresh non schedulabile: ${e.message}")
        }
    }

    /// Lettura no-IO del bit BLOCK_RECENT_APPS, sicura da qualunque thread:
    /// serve solo la cache @Volatile (mai Keystore). Stessa semantica
    /// fail-secure di [getMask]: cache non ancora popolata → tutto bloccato.
    /// Usata dal handler `openSystemRecents` per non fare da bypass dello
    /// strict mode (con bit 8 attivo il tap sull'icona recents del launcher
    /// deve fallire, non aprire la schermata che strict richiuderebbe).
    fun isRecentsBlockedCached(): Boolean {
        val m = cachedMask
        val effective = if (m >= 0) m else BlockingContract.ALL_OPTIONS_ENABLED
        return effective and BLOCK_RECENT_APPS != 0
    }

    fun invalidateCache() {
        version++
        val ctx = appContextRef
        if (ctx != null) {
            // Write path (raro, user-initiated: cambio opzioni / emergency
            // unblock / device admin / fail-safe): NON è sul hot path degli
            // window-event, quindi una read sincrona qui è accettabile e
            // garantisce zero staleness e zero finestra fail-secure dopo il
            // cambio. `version++` sopra annulla un eventuale async in volo.
            cachedMask = StrictModeStore.readMask(ctx)
            lastReadTime = System.currentTimeMillis()
        } else {
            // Mai avuto un context (invalidate prima di prime/getMask): la
            // prossima getMask farà il refresh async.
            cachedMask = -1
            lastReadTime = 0L
        }
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
            // Pattern condivisi con LauncherRecentsGate via RecentsDetector
            // (estrazione a comportamento invariato, vedi commenti lì).
            if (RecentsDetector.isRecentsWindow(packageName, className)) {
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
