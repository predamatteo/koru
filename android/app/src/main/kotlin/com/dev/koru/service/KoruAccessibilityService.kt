package com.dev.koru.service

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.dev.koru.browser.BrowserConfigLoader
import com.dev.koru.browser.BrowserUrlDetector
import com.dev.koru.browser.WebsiteMatcher
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.content.InAppContentDetector
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeProfile
import com.dev.koru.db.NativeWebsiteRule
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig
import com.dev.koru.strictmode.StrictModeEnforcer
import org.json.JSONObject
import java.util.Calendar

/**
 * Koru blocking engine running inside an AccessibilityService process.
 *
 * Event-driven su TYPE_WINDOW_STATE_CHANGED — quando rileva un'app bloccata
 * da un profilo attivo:
 *   1. Mostra l'overlay Koru via [OverlayManager] (ComposeView sopra tutto).
 *   2. Performa GLOBAL_ACTION_HOME per riportare l'utente alla home.
 *
 * L'OverlayManager deve vivere nello stesso processo dell'AccessibilityService
 * (cioè `:accessibility`) perché entrambi usano WindowManager attached a
 * quel processo. È un proprio OverlayManager distinto da quello di
 * LockForegroundService (che gira nel main process).
 */
class KoruAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "KoruAccessibility"
        const val ACTION_GO_HOME = "com.dev.koru.ACTION_GO_HOME"
        const val ACTION_RELOAD_PROFILES = "com.dev.koru.ACTION_RELOAD_PROFILES"

        /// Profile typeCombinations bit per "time interval enabled".
        /// Allineato a [ProfileType.time] in lib/core/constants/profile_types.dart.
        const val PROFILE_TYPE_TIME = 1

        @Volatile
        var instance: KoruAccessibilityService? = null
            private set

        fun performGoHomeAction() { instance?.performGlobalAction(GLOBAL_ACTION_HOME) }
        fun triggerReload() { instance?.forceReloadProfiles() }
    }

    private var profiles = emptyList<NativeProfile>()
    private var profileApps = mutableMapOf<Int, List<NativeAppRelation>>()
    private var websiteRulesCache = mutableMapOf<Int, List<NativeWebsiteRule>>()
    private var profileWifis = mapOf<Int, Set<String>>()
    private var profileIntervals = mapOf<Int, List<com.dev.koru.db.NativeInterval>>()
    private var lastProfileLoadTime = 0L
    private var currentlyBlockingPackage: String? = null
    private var lastForegroundPackage: String? = null

    private val skipPackages = setOf(
        // "android" è il pkg del framework: viene attribuito a TYPE_WINDOWS_CHANGED
        // emessi quando aggiungiamo il nostro overlay via WindowManager.addView.
        // Senza questo skip, checkAppBlocking("android") cade nel fall-through e
        // dismissa l'overlay che abbiamo appena mostrato (overlay flash al
        // primo blocco di un'app a freddo).
        "android",
        "com.android.systemui",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.miui.home",
        "com.sec.android.app.launcher",
        "com.huawei.android.launcher",
        "com.oppo.launcher",
        "com.oneplus.launcher",
        "com.coloros.safecenter",
    )

    private var actionReceiver: BroadcastReceiver? = null
    private var inAppDetector: InAppContentDetector? = null
    private var lastSectionEventTime = 0L
    private var lastDetectedSectionWireId: String? = null

    private var overlayManager: OverlayManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /// Runnable schedulati a tempo di scadenza del bypass, uno per ogni
    /// package attualmente bypassato. Servono a riattivare il blocco se
    /// l'utente resta dentro l'app anche dopo lo scadere della durata
    /// scelta (in quel caso non arrivano TYPE_WINDOW_STATE_CHANGED e
    /// checkAppBlocking non viene mai richiamato spontaneamente).
    private val pendingBypassExpiryChecks = mutableMapOf<String, Runnable>()

    /// Runnable schedulati a tempo di scadenza del daily limit, uno per
    /// ogni package con limite attivo non ancora superato. Servono a
    /// bloccare l'app quando il cap viene raggiunto MENTRE l'utente è
    /// ancora dentro: TYPE_WINDOW_STATE_CHANGED scatta solo all'apertura,
    /// quindi senza questo timer un utente che entra a 28' e resta
    /// continua ad usare l'app oltre i 30' senza che nulla lo fermi
    /// (bug osservato su Instagram).
    private val pendingLimitChecks = mutableMapOf<String, Runnable>()

    /// Throttle per TYPE_WINDOW_CONTENT_CHANGED nei browser: limita la lettura
    /// della URL bar (operazione relativamente costosa) a max 2/s.
    private var lastBrowserContentCheckMs = 0L
    private var lastBrowserContentPkg: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        inAppDetector = InAppContentDetector(applicationContext)
        overlayManager = OverlayManager(applicationContext).apply {
            onReturnHome = {
                performGlobalAction(GLOBAL_ACTION_HOME)
                dismiss()
            }
            onIntentionChosen = { pkg, intention ->
                try {
                    NativeDatabase.insertIntentionEvent(
                        applicationContext,
                        pkg,
                        intention,
                        System.currentTimeMillis(),
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to log intention: ${e.message}")
                }
            }
            onBypassOpen = { pkg, durationMs ->
                // Il bypass è stato registrato in OverlayManager.Companion via
                // markBypassed(pkg, durationMs) — resterà valido per la
                // durata scelta dall'utente indipendentemente dal fatto che
                // esca e rientri nell'app.
                Log.i(TAG, "Bypass granted for $pkg: ${durationMs / 60_000}min")
                try {
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        pkg,
                        eventType = 1, // SKIPPED
                        restrictionType = 0, // APP
                        timestamp = System.currentTimeMillis(),
                    )
                } catch (_: Exception) {}
                scheduleBypassExpiryCheck(pkg, durationMs)
                // Discriminator: nel flow APP_BLOCKED/USAGE_LIMIT/FOCUS_MODE/...
                // abbiamo fatto performGlobalAction(GLOBAL_ACTION_HOME), quindi
                // l'app non è più in foreground e va rilanciata via startActivity.
                // Nel flow BYPASS_EXPIRED invece showExtensionPrompt non fa HOME:
                // l'app è ancora in foreground, basta dismissare l'overlay (un
                // restart via Intent farebbe un fastidioso restart dell'activity).
                //
                // NB: NON usiamo `lastForegroundPackage == pkg` come signal — il
                // launcher è in skipPackages, quindi dopo HOME `lastForegroundPackage`
                // resta sull'app bloccata e il check sarebbe sempre true (era il
                // bug "Open anyway non rilancia mai l'app").
                val wasEntryBlock = overlayManager?.currentReason() != BlockReason.BYPASS_EXPIRED
                if (wasEntryBlock) {
                    // CRITICO: startActivity DEVE essere chiamato PRIMA del dismiss.
                    // Su Android 12+ i Background Activity Launch sono ristretti:
                    // un AccessibilityService che NON è in stato "user-interacting"
                    // viene bloccato dal sistema. Mentre l'overlay è ancora montato
                    // e l'utente ha appena tappato un button al suo interno, abbiamo
                    // la "interaction grace" che autorizza la launch. Se dismissiamo
                    // l'overlay PRIMA, la grace decade e startActivity fallisce
                    // silenziosamente (sintomo: app non si apre dopo "Open anyway").
                    val intent = packageManager.getLaunchIntentForPackage(pkg)
                    if (intent == null) {
                        Log.w(TAG, "No launch intent for $pkg — cannot relaunch after bypass")
                    } else {
                        intent.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
                        )
                        try {
                            startActivity(intent)
                            Log.i(TAG, "Launched $pkg after bypass")
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to launch $pkg: ${e.message}", e)
                        }
                    }
                    // Dismiss differito: lasciamo che la launch venga registrata
                    // dal system_server prima di smontare l'overlay.
                    mainHandler.postDelayed({ dismiss() }, 250L)
                } else {
                    dismiss()
                }
            }
        }

        actionReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_GO_HOME -> performGlobalAction(GLOBAL_ACTION_HOME)
                    ACTION_RELOAD_PROFILES -> forceReloadProfiles()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_GO_HOME)
            addAction(ACTION_RELOAD_PROFILES)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(actionReceiver, filter)
        }

        loadProfiles()
        Log.i(TAG, "=== Accessibility Service CONNECTED (overlay enabled) ===")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        // Content change / scroll dentro un browser → ricontrolla la URL bar.
        // TYPE_VIEW_SCROLLED copre il caso in cui l'utente scrolla nella pagina
        // o cambia tab (ascent pattern); TYPE_WINDOW_CONTENT_CHANGED è l'evento
        // più rumoroso — throttle serve a non saturare l'albero accessibility.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            if (!BrowserConfigLoader.isBrowser(applicationContext, pkg)) return
            val now = System.currentTimeMillis()
            val samePkg = pkg == lastBrowserContentPkg
            if (samePkg && now - lastBrowserContentCheckMs < 500) return
            lastBrowserContentCheckMs = now
            lastBrowserContentPkg = pkg
            if (now - lastProfileLoadTime > 10_000) loadProfiles()
            val root = try { rootInActiveWindow } catch (_: Exception) { null }
            if (root == null) {
                Log.w(TAG, "BROWSER ${event.eventType}: rootInActiveWindow null for $pkg")
            } else {
                checkWebsiteBlocking(pkg, root)
            }
            return
        }

        // TYPE_WINDOWS_CHANGED: cambio tab nel browser, nuova finestra, ecc.
        // Trattiamolo come uno state change (ri-check app + website).
        val isWindowChange = event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
        if (!isWindowChange) return

        // Strict Mode check (blocks settings/recent/uninstall based on mask)
        if (StrictModeEnforcer.handleEvent(this, event)) return

        if (skipPackages.contains(pkg) || pkg == packageName) {
            // Launcher o Koru stesso in foreground — NON dismiss overlay:
            // siamo probabilmente qui proprio perché abbiamo fatto HOME dopo
            // aver bloccato un'app. L'overlay deve restare visibile sopra il
            // launcher finché l'utente non apre un'app diversa (gestito sotto
            // in checkAppBlocking) o tocca "Go back" sull'overlay.
            return
        }

        lastForegroundPackage = pkg

        val now = System.currentTimeMillis()
        if (now - lastProfileLoadTime > 10_000) loadProfiles()

        val blockedByApp = checkAppBlocking(pkg)
        if (blockedByApp) return

        // In-app content blocking (Instagram Reels/Stories/Explore, YouTube Shorts)
        val detector = inAppDetector
        if (detector != null && detector.supports(pkg)) {
            val root = try { rootInActiveWindow } catch (_: Exception) { null }
            if (root != null && checkInAppContentBlocking(pkg, root)) return
        }

        if (BrowserConfigLoader.isBrowser(applicationContext, pkg)) {
            val root = try { rootInActiveWindow } catch (_: Exception) { null }
            if (root != null) checkWebsiteBlocking(pkg, root)
        }
    }

    /**
     * Schedula un prompt di estensione per [pkg] allo scadere del TTL del
     * bypass (scelto dall'utente dal duration picker).
     *
     * Serve a coprire il caso in cui l'utente resti dentro l'app bypassata
     * per l'intera durata scelta: senza cambio di window state il servizio
     * accessibility non richiama [checkAppBlocking] spontaneamente, quindi
     * il blocco non si riattiverebbe mai anche se il TTL è scaduto.
     *
     * Allo scadere, se l'utente è ancora dentro l'app ([lastForegroundPackage] == pkg),
     * mostriamo il prompt di estensione stile minimalist_phone: l'overlay
     * con [BlockReason.BYPASS_EXPIRED] propone "+1/5/15/30 min" oppure
     * "Close app" (HOME). Se l'utente è già uscito, no-op (al rientro
     * scatterà spontaneamente [checkAppBlocking]).
     */
    private fun scheduleBypassExpiryCheck(pkg: String, durationMs: Long) {
        // Cancella eventuale runnable precedente per lo stesso pkg
        // (es. utente ri-tocca "Open anyway" → nuova durata sostituisce la vecchia).
        pendingBypassExpiryChecks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }

        val r = object : Runnable {
            override fun run() {
                pendingBypassExpiryChecks.remove(pkg)
                // Double-check: il bypass potrebbe essere stato esteso nel frattempo.
                if (OverlayManager.isBypassed(pkg)) {
                    Log.d(TAG, "Bypass re-check for $pkg: still bypassed (renewed?), skipping")
                    return
                }
                // Se l'utente non è più nell'app bypassata, non serve far nulla:
                // al prossimo rientro scatterà normalmente checkAppBlocking.
                if (lastForegroundPackage != pkg) {
                    Log.d(TAG, "Bypass expired for $pkg but user not there (foreground=$lastForegroundPackage)")
                    return
                }
                Log.i(TAG, "Bypass TTL expired and user still in $pkg → showing extension prompt")
                showExtensionPrompt(pkg)
            }
        }
        pendingBypassExpiryChecks[pkg] = r
        // Piccolo grace (500ms) per evitare race col check `isBypassed`.
        mainHandler.postDelayed(r, durationMs + 500L)
    }

    /**
     * Pianifica un re-check del daily limit per [pkg] fra [remainingMs] ms.
     *
     * Risolve il caso "utente già dentro quando il cap viene toccato":
     * gli AccessibilityEvent TYPE_WINDOW_STATE_CHANGED scattano solo
     * all'apertura dell'app, quindi senza un timer un utente che entra
     * a 28' (cap=30') resta dentro per ore senza che il blocco si
     * riattivi mai. Il runnable rilancia [checkAppBlocking] che, se nel
     * frattempo `todayMs >= limitMs`, mostra l'overlay USAGE_LIMIT e fa
     * HOME. Se l'utente è uscito prima, no-op (rientrando scatterà
     * spontaneamente checkAppBlocking).
     *
     * Stesso pattern di [scheduleBypassExpiryCheck].
     */
    private fun scheduleLimitCheck(pkg: String, remainingMs: Long) {
        pendingLimitChecks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }
        if (remainingMs <= 0) {
            // Limite gia` raggiunto teoricamente: il caller (checkAppBlocking)
            // avrebbe dovuto bloccare. Difensivo, evitiamo postDelayed con 0.
            return
        }

        val r = object : Runnable {
            override fun run() {
                pendingLimitChecks.remove(pkg)
                if (lastForegroundPackage != pkg) {
                    Log.d(TAG, "Limit re-check for $pkg: user not there anymore (foreground=$lastForegroundPackage)")
                    return
                }
                if (OverlayManager.isBypassed(pkg)) {
                    Log.d(TAG, "Limit re-check for $pkg: bypass active, skipping")
                    return
                }
                Log.i(TAG, "Limit timer fired for $pkg, re-evaluating")
                checkAppBlocking(pkg)
            }
        }
        pendingLimitChecks[pkg] = r
        // +1s di grace: queryEvents potrebbe non aver ancora aggregato
        // la sessione corrente fino al ts esatto del cap. Meglio
        // sforare di 1s che fare un loop di re-schedule.
        mainHandler.postDelayed(r, remainingMs + 1_000L)
    }

    private fun cancelLimitCheck(pkg: String) {
        pendingLimitChecks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }
    }

    /**
     * Mostra l'overlay di estensione (time-up prompt) sopra l'app ancora
     * in foreground. A differenza del blocco "entry", NON facciamo HOME:
     * l'overlay vive sopra l'app; se l'utente sceglie un'estensione,
     * dismiss e basta; se sceglie "Close", fa HOME manualmente via
     * onReturnHome. Loggato come BLOCK_TRIGGERED per analytics.
     */
    private fun showExtensionPrompt(pkg: String) {
        val appLabel = getAppLabel(pkg)
        // Cerchiamo una relation app→profilo per ereditare la palette
        // dell'overlay config; in assenza usiamo DEFAULT.
        val relation = profileApps.values.asSequence().flatten()
            .firstOrNull { it.packageName == pkg }
        val config = OverlayConfig.fromJsonString(relation?.overlayConfigJson)
        val matchingProfile = profiles.firstOrNull { p ->
            profileApps[p.id]?.any { it.packageName == pkg } == true
        }
        mainHandler.post {
            overlayManager?.show(
                packageName = pkg,
                appLabel = appLabel,
                profileTitle = matchingProfile?.title ?: "Koru",
                reason = BlockReason.BYPASS_EXPIRED,
                config = config,
                profileEmoji = matchingProfile?.emoji,
            )
        }
        try {
            NativeDatabase.insertRestrictedAccessEvent(
                applicationContext,
                pkg,
                eventType = 0, // TRIGGERED
                restrictionType = 0, // APP
                timestamp = System.currentTimeMillis(),
            )
        } catch (_: Exception) {}
    }

    /**
     * Ritorna true se ha bloccato l'app (overlay mostrato + HOME).
     */
    private fun checkAppBlocking(packageName: String): Boolean {
        // Bypass timed: l'utente ha scelto una durata esplicita dal duration
        // picker. Finché quella durata non scade, non mostriamo l'overlay.
        if (OverlayManager.isBypassed(packageName)) return false

        // Quick-block / Pomodoro-work: blocca tutto tranne whitelist.
        // Lo stato è letto da QuickBlockStore (file su disco) perché
        // QuickBlockManager vive nel processo main e qui siamo in
        // `:accessibility` → memory isolation fra JVM.
        val qbSnapshot = QuickBlockStore.read(applicationContext)
        if (qbSnapshot.shouldBlock(packageName, System.currentTimeMillis())) {
            Log.w(TAG, ">>> BLOCKING APP (focus): $packageName")
            currentlyBlockingPackage = packageName
            val appLabel = getAppLabel(packageName)
            mainHandler.post {
                overlayManager?.show(
                    packageName = packageName,
                    appLabel = appLabel,
                    profileTitle = "Focus session",
                    reason = BlockReason.FOCUS_MODE,
                    config = OverlayConfig.DEFAULT,
                    profileEmoji = "\uD83C\uDFAF", // 🎯
                )
            }
            performGlobalAction(GLOBAL_ACTION_HOME)
            val now = System.currentTimeMillis()
            try {
                NativeDatabase.insertBlockSession(applicationContext, packageName, now)
                NativeDatabase.insertRestrictedAccessEvent(
                    applicationContext,
                    packageName,
                    eventType = 0,
                    restrictionType = 4, // FOCUS_MODE
                    timestamp = now,
                )
            } catch (_: Exception) {}
            return true
        }

        for (profile in profiles) {
            if (!isProfileActiveNow(profile)) continue

            val apps = profileApps[profile.id] ?: emptyList()
            val enabledApps = apps.filter { it.isEnabled }.map { it.packageName }

            val shouldBlock = when (profile.blockingMode) {
                0 -> enabledApps.contains(packageName)
                1 -> enabledApps.isNotEmpty() && !enabledApps.contains(packageName)
                else -> false
            }

            if (shouldBlock) {
                Log.w(TAG, ">>> BLOCKING APP: $packageName by '${profile.title}'")
                currentlyBlockingPackage = packageName
                val appLabel = getAppLabel(packageName)
                val relation = apps.firstOrNull { it.packageName == packageName }
                val config = OverlayConfig.fromJsonString(relation?.overlayConfigJson)
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = profile.title,
                        reason = BlockReason.APP_BLOCKED,
                        config = config,
                        profileEmoji = profile.emoji,
                    )
                }
                performGlobalAction(GLOBAL_ACTION_HOME)
                val now = System.currentTimeMillis()
                try {
                    NativeDatabase.insertBlockSession(applicationContext, packageName, now)
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        packageName,
                        eventType = 0, // TRIGGERED
                        restrictionType = 0, // APP
                        timestamp = now,
                    )
                } catch (_: Exception) {}
                sendBlockingStateEvent(true, packageName, profile)
                return true
            }
        }

        // Daily usage limit (globale, non legato a profili): se l'utente ha
        // superato i minuti concessi per questo pkg oggi → overlay.
        val limitMinutes = AppUsageLimitsStore.limitMinutesFor(applicationContext, packageName)
        if (limitMinutes > 0) {
            val todayMs = UsageCounter.todayForegroundMs(applicationContext, packageName)
            val limitMs = limitMinutes * 60_000L
            if (todayMs >= limitMs) {
                Log.w(TAG, ">>> BLOCKING APP (daily limit): $packageName " +
                    "${todayMs / 60_000}min used, cap=${limitMinutes}min")
                currentlyBlockingPackage = packageName
                cancelLimitCheck(packageName)
                val appLabel = getAppLabel(packageName)
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = "Daily limit",
                        reason = BlockReason.USAGE_LIMIT,
                        config = OverlayConfig.DEFAULT,
                        profileEmoji = "\u23F3", // ⏳
                    )
                }
                performGlobalAction(GLOBAL_ACTION_HOME)
                val now = System.currentTimeMillis()
                try {
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        packageName,
                        eventType = 0,
                        restrictionType = 3, // USAGE_LIMIT
                        timestamp = now,
                    )
                } catch (_: Exception) {}
                return true
            } else {
                // Cap non ancora raggiunto: pianifica un re-check fra
                // (limitMs - todayMs) ms così se l'utente resta dentro
                // l'app il blocco scatta nel momento in cui il cap viene
                // toccato, non solo al prossimo cambio di window state.
                // Senza questo timer, un utente che entra a 28' e resta
                // dentro continua a usare l'app oltre i 30' senza che
                // nulla lo fermi (bug osservato su Instagram).
                scheduleLimitCheck(packageName, limitMs - todayMs)
            }
        }

        // Nessun profilo blocca questo pkg — se avevamo un overlay, dismiss.
        if (currentlyBlockingPackage != null) {
            currentlyBlockingPackage = null
            mainHandler.post { overlayManager?.dismiss() }
            sendBlockingStateEvent(false, "", null)
        }
        return false
    }

    private fun checkInAppContentBlocking(
        packageName: String,
        root: AccessibilityNodeInfo,
    ): Boolean {
        val detected = inAppDetector?.detect(packageName, root) ?: return false

        // Debounce: avoid firing for the same detection within 1s
        val now = System.currentTimeMillis()
        if (detected.wireId == lastDetectedSectionWireId && now - lastSectionEventTime < 1_000) {
            return false
        }
        lastDetectedSectionWireId = detected.wireId
        lastSectionEventTime = now

        for (profile in profiles) {
            if (!isProfileActiveNow(profile)) continue
            val apps = profileApps[profile.id] ?: continue
            val relation = apps.firstOrNull { it.packageName == packageName } ?: continue

            // Se app è già bloccata interamente, il checkAppBlocking la gestisce.
            if (relation.isEnabled) continue

            val json = relation.blockedSectionsJson ?: continue
            if (!json.contains(detected.wireId)) continue

            Log.w(TAG, ">>> BLOCKING SECTION ${detected.wireId} in $packageName by '${profile.title}'")
            val appLabel = getAppLabel(packageName)
            val config = OverlayConfig.fromJsonString(relation.overlayConfigJson)
            mainHandler.post {
                overlayManager?.show(
                    packageName = packageName,
                    appLabel = appLabel,
                    profileTitle = profile.title,
                    reason = BlockReason.SECTION_BLOCKED,
                    config = config,
                    profileEmoji = profile.emoji,
                )
            }
            performGlobalAction(GLOBAL_ACTION_HOME)
            try {
                NativeDatabase.insertBlockSession(
                    applicationContext,
                    "$packageName/${detected.wireId}",
                    now,
                )
                NativeDatabase.insertRestrictedAccessEvent(
                    applicationContext,
                    packageName,
                    eventType = 0,
                    restrictionType = 1, // SECTION
                    timestamp = now,
                )
            } catch (_: Exception) {}
            sendSectionEvent(packageName, detected.wireId, profile)
            return true
        }
        return false
    }

    private fun checkWebsiteBlocking(packageName: String, rootNode: AccessibilityNodeInfo) {
        val configs = BrowserConfigLoader.getConfigsForPackage(applicationContext, packageName)
        if (configs.isEmpty()) {
            Log.w(TAG, "  → no browser configs for $packageName")
            return
        }

        val detected = BrowserUrlDetector.detect(rootNode, configs)
        if (detected == null) {
            Log.d(TAG, "  → URL bar not detected (configs=${configs.size})")
            return
        }
        Log.i(TAG, "  URL detected: domain=${detected.domain} full=${detected.fullUrl}")

        if (websiteRulesCache.isEmpty()) {
            Log.w(TAG, "  → websiteRulesCache is EMPTY")
            return
        }

        for ((profileId, rules) in websiteRulesCache) {
            Log.d(TAG, "  profile $profileId has ${rules.size} rules: ${rules.map { "${it.name}(type=${it.blockingType},any=${it.isAnywhereInUrl})" }}")
            if (WebsiteMatcher.matchesAny(rules, detected.fullUrl, detected.domain)) {
                Log.w(TAG, ">>> BLOCKING SITE: ${detected.domain} by profile $profileId")
                val matchedProfile = profiles.firstOrNull { it.id == profileId }
                val profileTitle = matchedProfile?.title ?: "Koru"
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = detected.domain,
                        profileTitle = profileTitle,
                        reason = BlockReason.WEBSITE_BLOCKED,
                        profileEmoji = matchedProfile?.emoji,
                    )
                }
                performGlobalAction(GLOBAL_ACTION_HOME)
                val now = System.currentTimeMillis()
                try {
                    NativeDatabase.insertBlockSession(applicationContext, detected.domain, now)
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        packageName,
                        eventType = 0,
                        restrictionType = 2, // WEBSITE
                        timestamp = now,
                    )
                } catch (_: Exception) {}
                return
            }
        }
    }

    private fun isProfileActiveNow(profile: NativeProfile): Boolean {
        if (profile.pausedUntil < 0) return false
        if (profile.pausedUntil > 0 && profile.pausedUntil > System.currentTimeMillis()) return false

        val cal = Calendar.getInstance()
        val todayFlag = when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 4
            Calendar.THURSDAY -> 8
            Calendar.FRIDAY -> 16
            Calendar.SATURDAY -> 32
            Calendar.SUNDAY -> 64
            else -> 0
        }
        if (profile.dayFlags and todayFlag == 0) return false
        if (profile.onUntil > 0 && System.currentTimeMillis() > profile.onUntil) return false

        // Time interval check: se il profilo ha typeCombinations con bit
        // PROFILE_TYPE_TIME e ci sono intervals enabled, l'orario corrente
        // deve cadere in almeno uno di essi (cross-midnight supportato).
        val hasTimeType = (profile.typeCombinations and PROFILE_TYPE_TIME) != 0
        val intervals = profileIntervals[profile.id] ?: emptyList()
        if (hasTimeType && intervals.isNotEmpty()) {
            val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 +
                cal.get(Calendar.MINUTE)
            val inAny = intervals.any { iv ->
                val from = iv.fromMinutes
                val to = iv.toMinutes
                if (from == to) {
                    true // 24h
                } else if (from < to) {
                    nowMinutes in from until to
                } else {
                    // cross-midnight (es. 22:00 → 06:00)
                    nowMinutes >= from || nowMinutes < to
                }
            }
            if (!inAny) return false
        }

        // Wifi constraint (Phase 2): se il profilo ha almeno un SSID
        // configurato, attivo solo se l'SSID corrente matcha. Se non
        // possiamo leggere il SSID (permesso location non concesso)
        // trattiamo come "no match" → profilo inattivo per sicurezza.
        val wifiSet = profileWifis[profile.id]
        if (wifiSet != null && wifiSet.isNotEmpty()) {
            val current = getCurrentWifiSsid()
            if (current == null || !wifiSet.contains(current)) return false
        }
        return true
    }

    private fun loadProfiles() {
        try {
            NativeDatabase.close()
            profiles = NativeDatabase.getEnabledProfiles(applicationContext)
            profileApps.clear()
            websiteRulesCache.clear()
            val intervalsByProfile = mutableMapOf<Int, List<com.dev.koru.db.NativeInterval>>()
            for (p in profiles) {
                profileApps[p.id] = NativeDatabase.getAppRelationsForProfile(applicationContext, p.id)
                intervalsByProfile[p.id] = NativeDatabase.getIntervalsForProfile(applicationContext, p.id)
            }
            profileIntervals = intervalsByProfile
            websiteRulesCache.putAll(NativeDatabase.getAllWebsiteRulesForEnabledProfiles(applicationContext))
            profileWifis = NativeDatabase.getWifiSsidsByProfile(applicationContext)
            lastProfileLoadTime = System.currentTimeMillis()
            Log.d(TAG, "Loaded ${profiles.size} profiles, ${profileWifis.size} with wifi constraints, " +
                "${profileIntervals.values.sumOf { it.size }} intervals")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading profiles: ${e.message}")
            profiles = emptyList()
            profileApps.clear()
            websiteRulesCache.clear()
            profileWifis = emptyMap()
            profileIntervals = emptyMap()
        }
    }

    /// Legge il SSID corrente via WifiManager (stesso pattern di
    /// BlockingMethodChannel.getCurrentWifiSsid). Ritorna null se
    /// non connessi o mancano permessi.
    private fun getCurrentWifiSsid(): String? {
        return try {
            val wm = applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
            val info = wm?.connectionInfo ?: return null
            val ssid = info.ssid
            if (ssid == null || ssid == "<unknown ssid>") return null
            if (ssid.length >= 2 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid.substring(1, ssid.length - 1)
            } else {
                ssid
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun forceReloadProfiles() {
        Log.i(TAG, "Force reloading profiles")
        loadProfiles()
        lastForegroundPackage?.let { checkAppBlocking(it) }
    }

    private fun getAppLabel(packageName: String): String = try {
        val pm = packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        packageName
    }

    private fun sendBlockingStateEvent(
        isBlocking: Boolean,
        packageName: String,
        profile: NativeProfile?,
    ) {
        val json = JSONObject().apply {
            put("type", "BLOCKING_STATE")
            put("isBlocking", isBlocking)
            put("packageName", packageName)
            put("profileId", profile?.id ?: -1)
            put("profileTitle", profile?.title ?: "")
        }
        ServiceEventChannel.sendEvent(json.toString())
    }

    private fun sendSectionEvent(packageName: String, sectionWireId: String, profile: NativeProfile) {
        val json = JSONObject().apply {
            put("type", "IN_APP_SECTION_DETECTED")
            put("packageName", packageName)
            put("section", sectionWireId)
            put("profileId", profile.id)
            put("profileTitle", profile.title)
        }
        ServiceEventChannel.sendEvent(json.toString())
    }

    override fun onInterrupt() {
        Log.w(TAG, "Interrupted")
    }

    override fun onDestroy() {
        instance = null
        actionReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        actionReceiver = null
        pendingBypassExpiryChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingBypassExpiryChecks.clear()
        pendingLimitChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingLimitChecks.clear()
        overlayManager?.destroy()
        overlayManager = null
        NativeDatabase.close()
        super.onDestroy()
    }
}
