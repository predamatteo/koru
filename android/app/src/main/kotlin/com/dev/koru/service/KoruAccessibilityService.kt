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

        @Volatile
        var instance: KoruAccessibilityService? = null
            private set

        fun performGoHomeAction() { instance?.performGlobalAction(GLOBAL_ACTION_HOME) }
        fun triggerReload() { instance?.forceReloadProfiles() }
    }

    private var profiles = emptyList<NativeProfile>()
    private var profileApps = mutableMapOf<Int, List<NativeAppRelation>>()
    private var websiteRulesCache = mutableMapOf<Int, List<NativeWebsiteRule>>()
    private var lastProfileLoadTime = 0L
    private var currentlyBlockingPackage: String? = null
    private var lastForegroundPackage: String? = null

    private val skipPackages = setOf(
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
            onBypassOpen = { pkg ->
                // bypass già registrato in OverlayManager.Companion via markBypassed.
                // Logga BLOCK_SKIPPED per analytics.
                try {
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        pkg,
                        eventType = 1, // SKIPPED
                        restrictionType = 0, // APP
                        timestamp = System.currentTimeMillis(),
                    )
                } catch (_: Exception) {}
                dismiss()
                val intent = packageManager.getLaunchIntentForPackage(pkg)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        startActivity(intent)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to launch $pkg: ${e.message}")
                    }
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
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

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
     * Ritorna true se ha bloccato l'app (overlay mostrato + HOME).
     */
    private fun checkAppBlocking(packageName: String): Boolean {
        // Bypass temporaneo (utente ha toccato "Open anyway" sull'overlay).
        if (OverlayManager.isBypassed(packageName)) return false

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
        if (configs.isEmpty()) return

        val detected = BrowserUrlDetector.detect(rootNode, configs) ?: return

        for ((profileId, rules) in websiteRulesCache) {
            if (WebsiteMatcher.matchesAny(rules, detected.fullUrl, detected.domain)) {
                Log.w(TAG, ">>> BLOCKING SITE: ${detected.domain} by profile $profileId")
                val profileTitle = profiles.firstOrNull { it.id == profileId }?.title ?: "Koru"
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = detected.domain,
                        profileTitle = profileTitle,
                        reason = BlockReason.WEBSITE_BLOCKED,
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
        return true
    }

    private fun loadProfiles() {
        try {
            NativeDatabase.close()
            profiles = NativeDatabase.getEnabledProfiles(applicationContext)
            profileApps.clear()
            websiteRulesCache.clear()
            for (p in profiles) {
                profileApps[p.id] = NativeDatabase.getAppRelationsForProfile(applicationContext, p.id)
            }
            websiteRulesCache.putAll(NativeDatabase.getAllWebsiteRulesForEnabledProfiles(applicationContext))
            lastProfileLoadTime = System.currentTimeMillis()
            Log.d(TAG, "Loaded ${profiles.size} profiles")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading profiles: ${e.message}")
            profiles = emptyList()
            profileApps.clear()
            websiteRulesCache.clear()
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
        overlayManager?.destroy()
        overlayManager = null
        NativeDatabase.close()
        super.onDestroy()
    }
}
