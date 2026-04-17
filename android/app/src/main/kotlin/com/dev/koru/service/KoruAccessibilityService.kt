package com.dev.koru.service

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
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
import com.dev.koru.strictmode.StrictModeEnforcer
import org.json.JSONObject
import java.util.Calendar

/**
 * Koru blocking engine running inside an AccessibilityService process.
 *
 * Reacts event-driven to TYPE_WINDOW_STATE_CHANGED for immediate blocking and
 * URL parsing. Works in parallel with LockForegroundService's LockRunnable
 * (polling-based backup loop).
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

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        inAppDetector = InAppContentDetector(applicationContext)

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
        Log.i(TAG, "=== Accessibility Service CONNECTED ===")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        // Strict Mode check (blocks settings/recent/uninstall based on mask)
        if (StrictModeEnforcer.handleEvent(this, event)) return

        if (skipPackages.contains(pkg) || pkg == packageName) {
            if (currentlyBlockingPackage != null) currentlyBlockingPackage = null
            return
        }

        lastForegroundPackage = pkg

        val now = System.currentTimeMillis()
        if (now - lastProfileLoadTime > 10_000) loadProfiles()

        checkAppBlocking(pkg)

        // In-app content blocking (Instagram Reels/Stories/Explore, YouTube Shorts)
        val detector = inAppDetector
        if (detector != null && detector.supports(pkg)) {
            val root = try { rootInActiveWindow } catch (_: Exception) { null }
            if (root != null) checkInAppContentBlocking(pkg, root)
        }

        if (BrowserConfigLoader.isBrowser(applicationContext, pkg)) {
            val root = try { rootInActiveWindow } catch (_: Exception) { null }
            if (root != null) checkWebsiteBlocking(pkg, root)
        }
    }

    private fun checkInAppContentBlocking(packageName: String, root: AccessibilityNodeInfo) {
        val detected = inAppDetector?.detect(packageName, root) ?: return

        // Debounce: avoid firing for the same detection within 1s
        val now = System.currentTimeMillis()
        if (detected.wireId == lastDetectedSectionWireId && now - lastSectionEventTime < 1_000) {
            return
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
            performGlobalAction(GLOBAL_ACTION_HOME)
            try {
                NativeDatabase.insertBlockSession(
                    applicationContext,
                    "$packageName/${detected.wireId}",
                    now,
                )
            } catch (_: Exception) {}
            sendSectionEvent(packageName, detected.wireId, profile)
            return
        }
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

    private fun checkAppBlocking(packageName: String) {
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
                performGlobalAction(GLOBAL_ACTION_HOME)
                try {
                    NativeDatabase.insertBlockSession(applicationContext, packageName, System.currentTimeMillis())
                } catch (_: Exception) {}
                return
            }
        }
        if (currentlyBlockingPackage != null) currentlyBlockingPackage = null
    }

    private fun checkWebsiteBlocking(packageName: String, rootNode: AccessibilityNodeInfo) {
        val configs = BrowserConfigLoader.getConfigsForPackage(applicationContext, packageName)
        if (configs.isEmpty()) return

        val detected = BrowserUrlDetector.detect(rootNode, configs) ?: return

        for ((profileId, rules) in websiteRulesCache) {
            if (WebsiteMatcher.matchesAny(rules, detected.fullUrl, detected.domain)) {
                Log.w(TAG, ">>> BLOCKING SITE: ${detected.domain} by profile $profileId")
                performGlobalAction(GLOBAL_ACTION_HOME)
                try {
                    NativeDatabase.insertBlockSession(applicationContext, detected.domain, System.currentTimeMillis())
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

    override fun onInterrupt() {
        Log.w(TAG, "Interrupted")
    }

    override fun onDestroy() {
        instance = null
        actionReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        actionReceiver = null
        NativeDatabase.close()
        super.onDestroy()
    }
}
