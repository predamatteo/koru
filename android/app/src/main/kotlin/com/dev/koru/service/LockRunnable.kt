package com.dev.koru.service

import android.content.Context
import android.os.PowerManager
import android.util.Log
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import java.util.Calendar

class LockRunnable(
    private val context: Context,
    private val onBlock: (String, String, NativeProfile, NativeAppRelation?) -> Unit,
    private val onUnblock: () -> Unit,
) : Runnable {

    companion object {
        private const val TAG = "LockRunnable"
        private const val POLL_INTERVAL_MS = 300L
        private const val PROFILE_RELOAD_INTERVAL = 100 // ~30s

        const val MODE_BLOCKLIST = 0
        const val MODE_ALLOWLIST = 1
        const val TYPE_TIME = 1
    }

    @Volatile var isRunning = true
    @Volatile var needsReload = false

    private var profiles = emptyList<NativeProfile>()
    private var profileApps = mutableMapOf<Int, List<NativeAppRelation>>()
    private var profileIntervals = mutableMapOf<Int, List<NativeInterval>>()
    private var iterationCount = 0
    private var currentlyBlockingPackage: String? = null

    private val skipPackages = mutableSetOf<String>().apply {
        add(context.packageName)
        add("com.android.systemui")
        add("com.android.launcher3")
        add("com.google.android.apps.nexuslauncher")
        add("com.miui.home")
        add("com.sec.android.app.launcher")
        add("com.huawei.android.launcher")
        add("com.oppo.launcher")
        add("com.oneplus.launcher")
    }

    override fun run() {
        Log.i(TAG, "=== Blocking loop STARTED ===")
        Thread.sleep(1000) // wait for DB to be ready
        loadProfiles()

        while (isRunning) {
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (pm.isInteractive) checkAndBlock()

                iterationCount++
                if (needsReload || iterationCount % PROFILE_RELOAD_INTERVAL == 0) {
                    needsReload = false
                    loadProfiles()
                }

                Thread.sleep(POLL_INTERVAL_MS)
            } catch (e: InterruptedException) {
                Log.i(TAG, "Blocking loop interrupted")
                break
            } catch (e: Exception) {
                Log.e(TAG, "Error in blocking loop", e)
                try { Thread.sleep(1000) } catch (_: InterruptedException) { break }
            }
        }
        Log.i(TAG, "=== Blocking loop STOPPED ===")
    }

    fun reloadProfiles() = loadProfiles()

    private fun loadProfiles() {
        try {
            profiles = NativeDatabase.getEnabledProfiles(context)
            profileApps.clear()
            profileIntervals.clear()
            for (profile in profiles) {
                profileApps[profile.id] = NativeDatabase.getAppRelationsForProfile(context, profile.id)
                if (profile.typeCombinations and TYPE_TIME != 0) {
                    profileIntervals[profile.id] = NativeDatabase.getIntervalsForProfile(context, profile.id)
                }
                Log.i(TAG, "Profile '${profile.title}' (id=${profile.id}): mode=${if (profile.blockingMode == 0) "BLOCKLIST" else "ALLOWLIST"}, apps=${profileApps[profile.id]?.map { it.packageName }}")
            }
            Log.i(TAG, "Loaded ${profiles.size} active profiles")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading profiles: ${e.message}", e)
            profiles = emptyList()
            profileApps.clear()
            profileIntervals.clear()
        }
    }

    private fun checkAndBlock() {
        if (profiles.isEmpty()) return

        val foreground = ForegroundDetector.detect(context) ?: run {
            if (iterationCount % 100 == 0) Log.w(TAG, "ForegroundDetector returned null")
            return
        }
        val pkg = foreground.primaryPackage ?: return

        if (skipPackages.contains(pkg)) {
            if (currentlyBlockingPackage != null) {
                currentlyBlockingPackage = null
                onUnblock()
            }
            return
        }

        if (iterationCount % 33 == 0) Log.d(TAG, "Foreground: $pkg")

        for (profile in profiles) {
            if (!isProfileActiveNow(profile)) continue

            val relation = findBlockingRelation(profile, pkg) ?: continue
            if (currentlyBlockingPackage != pkg) {
                currentlyBlockingPackage = pkg
                val appLabel = getAppLabel(pkg)
                Log.w(TAG, ">>> BLOCKING $pkg ($appLabel) by profile '${profile.title}'")
                onBlock(pkg, appLabel, profile, relation)
                try {
                    NativeDatabase.insertBlockSession(context, pkg, System.currentTimeMillis())
                } catch (_: Exception) {}
            }
            return
        }

        if (currentlyBlockingPackage != null) {
            Log.d(TAG, "<<< UNBLOCKING (switched to $pkg)")
            currentlyBlockingPackage = null
            onUnblock()
        }
    }

    /// Returns the AppProfileRelation that triggers the block (so caller can
    /// extract overlayConfigJson / blockedSectionsJson), or null if no block.
    private fun findBlockingRelation(profile: NativeProfile, packageName: String): NativeAppRelation? {
        val apps = profileApps[profile.id] ?: return null
        val enabledApps = apps.filter { it.isEnabled }

        return when (profile.blockingMode) {
            MODE_BLOCKLIST -> enabledApps.firstOrNull { it.packageName == packageName }
            MODE_ALLOWLIST ->
                if (enabledApps.isNotEmpty() && enabledApps.none { it.packageName == packageName }) {
                    // synthetic relation: allowlist doesn't have a per-app overlay config
                    NativeAppRelation(packageName, profile.id, true, null, null)
                } else null
            else -> null
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

        if (profile.typeCombinations and TYPE_TIME != 0) {
            val intervals = profileIntervals[profile.id] ?: emptyList()
            if (intervals.isNotEmpty()) {
                val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                val inInterval = intervals.any { iv ->
                    if (iv.fromMinutes <= iv.toMinutes) {
                        nowMinutes in iv.fromMinutes..iv.toMinutes
                    } else {
                        nowMinutes >= iv.fromMinutes || nowMinutes <= iv.toMinutes
                    }
                }
                if (!inInterval) return false
            }
        }

        if (profile.onUntil > 0 && System.currentTimeMillis() > profile.onUntil) return false
        return true
    }

    private fun getAppLabel(packageName: String): String = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        packageName
    }
}
