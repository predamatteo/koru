package com.dev.koru.service

import android.content.Context
import android.os.PowerManager
import android.util.Log
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import java.util.Calendar

/**
 * Polling-based blocking engine eseguito da [LockForegroundService] come
 * BACKUP indipendente dall'AccessibilityService.
 *
 * Architettura defense-in-depth: se [KoruAccessibilityService.instance] è
 * vivo, lui fa tutto (event-driven, latenza ~0ms) e questo loop si tira da
 * parte per non duplicare overlay/HOME. Se invece l'accessibility è morta
 * (killata da OEM aggressive battery management, crash, disabilitazione
 * manuale), questo loop continua a far rispettare profili E daily limits
 * con polling 300ms — l'utente vede comunque il blocco.
 *
 * Senza questo backup il blocking è single-point-of-failure: una sola
 * brick run del servizio accessibility = limiti completamente ignorati.
 */
class LockRunnable(
    private val context: Context,
    private val onBlock: (String, String, NativeProfile, NativeAppRelation?) -> Unit,
    private val onLimitBlock: (pkg: String, appLabel: String, limitMinutes: Int, todayMs: Long) -> Unit,
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

    /// Ultimo pkg bypassato che era effettivamente foreground. Mirror del
    /// tracking in KoruAccessibilityService: quando il foreground cambia
    /// verso un'altra app (o launcher), il bypass del pkg precedente viene
    /// revocato. Garantisce che il backup polling abbia lo stesso behavior
    /// del path primario quando l'AccessibilityService è morto.
    /// Granularità: limitata al periodo di poll (300ms/5s/10s).
    private var lastBypassedForegroundPkg: String? = null

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

        // O12: PowerManager risolto una sola volta. getSystemService non
        // è gratis (lookup ServiceManager) e qui era nel hot loop.
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager

        while (isRunning) {
            try {
                val interactive = pm.isInteractive
                if (interactive) checkAndBlock()

                iterationCount++
                if (needsReload || iterationCount % PROFILE_RELOAD_INTERVAL == 0) {
                    needsReload = false
                    loadProfiles()
                }

                // Adaptive backoff: il polling 300ms è il backup di emergenza
                // per quando l'AccessibilityService è morto. In quel caso ci
                // serve reattività vera (300ms = max 300ms di lag prima del
                // blocco). Quando invece accessibility è vivo è lui il path
                // primario, e qui basta un check ogni 5s per "siamo ancora
                // qui pronti se cade". Schermo spento: 10s, irrilevante
                // qualunque foreground app perché l'utente non la sta usando.
                val sleepMs = when {
                    !interactive -> 10_000L
                    KoruAccessibilityService.instance != null -> 5_000L
                    else -> POLL_INTERVAL_MS
                }
                Thread.sleep(sleepMs)
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
        // NOTE: rimosso il vecchio early-return su `profiles.isEmpty()`:
        // i daily limits sono globali, non profile-scoped, quindi vanno
        // controllati anche se l'utente ha 0 profili abilitati.

        // O12: lookback ridotto a 30s. Default più lungo causava
        // ForegroundDetector a scansionare ~60s di UsageEvents ogni
        // 300ms = uso CPU non necessario. 30s è abbastanza per coprire
        // il caso in cui torniamo dal sleep di un cycle precedente.
        val foreground = ForegroundDetector.detect(context, lookbackMs = 30_000L) ?: run {
            if (iterationCount % 100 == 0) Log.w(TAG, "ForegroundDetector returned null")
            return
        }
        val pkg = foreground.primaryPackage ?: return

        // Auto-revoke del bypass on app exit. Se l'ultimo pkg bypassato
        // tracciato è diverso dal foreground attuale (sia un'altra app,
        // sia skipPackages → launcher), l'utente è uscito → revoca il
        // bypass residuo. Allinea il path backup al primario in
        // KoruAccessibilityService. UsageStats qui è già la fonte
        // authoritative del foreground (ForegroundDetector sopra),
        // quindi non serve doppia verifica.
        val prevBypassed = lastBypassedForegroundPkg
        if (prevBypassed != null && pkg != prevBypassed) {
            OverlayManager.clearBypass(prevBypassed)
            lastBypassedForegroundPkg = null
            Log.i(TAG, "[BACKUP] Bypass auto-revoke: user left $prevBypassed (now $pkg)")
        }

        if (skipPackages.contains(pkg)) {
            if (currentlyBlockingPackage != null) {
                currentlyBlockingPackage = null
                onUnblock()
            }
            return
        }

        // BACKUP-ONLY: se l'AccessibilityService è vivo, lui è il path
        // primario (event-driven, niente polling lag). Ci tiriamo da parte
        // per evitare doppio overlay e doppia HOME. Manteniamo lo state
        // pulito così, se in futuro accessibility cade, ripartiamo netti.
        if (KoruAccessibilityService.instance != null) {
            currentlyBlockingPackage = null
            return
        }

        if (iterationCount % 33 == 0) Log.d(TAG, "[BACKUP] Foreground: $pkg")

        // 1) Daily usage limit FIRST: deve vincere sul profile block quando
        //    il cap e' superato, ed è valutato PRIMA del bypass perché un
        //    "Open anyway" su un blocco di profilo non ricarica il budget
        //    cumulativo del cap (era il bug "+5 min all'infinito sul limite
        //    passando dal blocco di profilo"). Coerente con
        //    KoruAccessibilityService (path primario). Eccezione SOLO
        //    non-strict, [OverlayManager.isLimitBypassActive]: un bypass nato
        //    DAL limite (USAGE_LIMIT / BYPASS_EXPIRED) lo sospende per la
        //    durata scelta. STRICT ⇒ hard cap assoluto: blocca sempre,
        //    ignorando qualsiasi bypass (anche un limit-bypass residuo da
        //    quando l'app era non-strict). Allineato a checkAppBlocking.
        val limitMinutes = AppUsageLimitsStore.limitMinutesFor(context, pkg)
        if (limitMinutes > 0 &&
            (AppUsageLimitsStore.isStrictFor(context, pkg) ||
                !OverlayManager.isLimitBypassActive(pkg))
        ) {
            val todayMs = UsageCounter.todayForegroundMs(context, pkg)
            if (todayMs >= limitMinutes * 60_000L) {
                if (currentlyBlockingPackage != pkg) {
                    currentlyBlockingPackage = pkg
                    val appLabel = getAppLabel(pkg)
                    Log.w(TAG, ">>> [BACKUP] BLOCKING $pkg (daily limit ${todayMs / 60_000}/${limitMinutes}min)")
                    onLimitBlock(pkg, appLabel, limitMinutes, todayMs)
                    try {
                        NativeDatabase.insertRestrictedAccessEvent(
                            context,
                            pkg,
                            eventType = 0, // TRIGGERED
                            restrictionType = 3, // USAGE_LIMIT
                            timestamp = System.currentTimeMillis(),
                        )
                    } catch (_: Exception) {}
                }
                return
            }
        }

        // 2) Bypass attivo (utente ha scelto "Open anyway" con TTL): rispetta
        //    il bypass come fa l'AccessibilityService, senza rifare HOME.
        //    Tracciamo il pkg come "bypassato e in foreground" così che il
        //    prossimo cambio di foreground possa innescare l'auto-revoke. Il
        //    cap è già stato controllato sopra (un bypass di profilo non lo
        //    nasconde più).
        if (OverlayManager.isBypassed(pkg)) {
            lastBypassedForegroundPkg = pkg
            if (currentlyBlockingPackage != null) {
                currentlyBlockingPackage = null
                onUnblock()
            }
            return
        }

        // 3) Profile-based blocking (logica originale).
        // O13: snapshot tramite toList() — loadProfiles() può sostituire
        // l'intera lista da un altro callback (reloadProfiles via Flutter
        // bridge). Iterando direttamente su `profiles` si rischiava
        // ConcurrentModificationException quando il broadcast arrivava
        // a metà ciclo.
        val profilesSnapshot = profiles.toList()
        for (profile in profilesSnapshot) {
            if (!isProfileActiveNow(profile)) continue

            val relation = findBlockingRelation(profile, pkg) ?: continue
            if (currentlyBlockingPackage != pkg) {
                currentlyBlockingPackage = pkg
                val appLabel = getAppLabel(pkg)
                Log.w(TAG, ">>> [BACKUP] BLOCKING $pkg ($appLabel) by profile '${profile.title}'")
                onBlock(pkg, appLabel, profile, relation)
                try {
                    NativeDatabase.insertBlockSession(context, pkg, System.currentTimeMillis())
                } catch (_: Exception) {}
            }
            return
        }

        if (currentlyBlockingPackage != null) {
            Log.d(TAG, "<<< [BACKUP] UNBLOCKING (switched to $pkg)")
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
