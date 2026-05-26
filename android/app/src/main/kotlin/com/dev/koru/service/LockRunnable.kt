package com.dev.koru.service

import android.content.Context
import android.os.PowerManager
import android.util.Log
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.overlay.BlockReason
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
    /// Callback per il blocco FOCUS_MODE (quick-block / pomodoro work phase).
    /// CR-01: il backup ora applica anche il focus, prima era assente — se
    /// l'AccessibilityService moriva durante una sessione focus, le app
    /// non-whitelist restavano sbloccate. Il wiring (overlay FOCUS_MODE +
    /// performGoHome + restrictionType=4) vive in [LockForegroundService].
    private val onFocusBlock: (pkg: String, appLabel: String) -> Unit,
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
    private var profileWifis = mapOf<Int, Set<String>>()
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
                // Intervals caricati INCONDIZIONATAMENTE (prima solo se il bit
                // TYPE_TIME era attivo): l'evaluator decide lui se gating-are
                // sul tempo (controlla il bit typeCombinations), così la
                // semantica è identica al path accessibility e non c'è un
                // ramo di caricamento divergente da tenere allineato.
                profileIntervals[profile.id] = NativeDatabase.getIntervalsForProfile(context, profile.id)
                Log.i(TAG, "Profile '${profile.title}' (id=${profile.id}): mode=${if (profile.blockingMode == 0) "BLOCKLIST" else "ALLOWLIST"}, apps=${profileApps[profile.id]?.map { it.packageName }}")
            }
            // CR-03: vincolo wifi anche nel backup, via lo stesso store del
            // path accessibility.
            profileWifis = NativeDatabase.getWifiSsidsByProfile(context)
            Log.i(TAG, "Loaded ${profiles.size} active profiles, ${profileWifis.size} with wifi constraints")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading profiles: ${e.message}", e)
            profiles = emptyList()
            profileApps.clear()
            profileIntervals.clear()
            profileWifis = emptyMap()
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

        // Decisione DELEGATA a [BlockPolicyEvaluator] — STESSA logica del path
        // accessibility (focus → daily limit → bypass profilo → profile loop).
        // Prima il backup aveva una copia divergente: niente focus (CR-01),
        // niente wifi (CR-03), intervalli CHIUSI invece di half-open. Ora è
        // l'evaluator a decidere e qui restano solo i side-effect del backup.
        //
        // Letture d'ambiente (lette qui, non dall'AccessibilityService che è
        // morto se siamo arrivati fin qui):
        // - focusShouldBlock: QuickBlockStore (CR-01, prima assente nel backup).
        // - limit (SEC-03 guarded): solo se esiste un cap, evita la query usage.
        // - currentWifiSsid: helper condiviso (CR-03).
        val qb = QuickBlockStore.read(context)
        val focusShouldBlock = qb.shouldBlock(pkg, System.currentTimeMillis())

        val limitEntry = AppUsageLimitsStore.entryFor(context, pkg)
        val limitMinutes = limitEntry?.minutes ?: 0
        val isLimitStrict = limitEntry?.strict ?: true
        // SEC-03: variante GUARDATA anche nel backup, così il cap resta scattato
        // anche con AccessibilityService morto e data spostata indietro.
        val limitTodayMs = if (limitMinutes > 0) {
            UsageCounter.guardedTodayForegroundMs(context, pkg)
        } else 0L

        // O13: snapshot tramite toList() — loadProfiles() può sostituire
        // l'intera lista da un altro callback (reloadProfiles via Flutter
        // bridge); copiare evita ConcurrentModificationException.
        val cal = Calendar.getInstance()
        val decision = BlockPolicyEvaluator.evaluate(
            BlockQuery(
                packageName = pkg,
                profiles = profiles.toList(),
                profileApps = profileApps.toMap(),
                profileIntervals = profileIntervals.toMap(),
                profileWifis = profileWifis,
                limitMinutes = limitMinutes,
                isLimitStrict = isLimitStrict,
                limitTodayMs = limitTodayMs,
                focusShouldBlock = focusShouldBlock,
                // Scope per-app (null): il backup non ha node tree, quindi non
                // valuta sezioni/siti → solo bypass per-app, come prima.
                bypassReasonFor = { scope -> OverlayManager.bypassReason(pkg, scope) },
                nowWallMs = System.currentTimeMillis(),
                nowMinutesOfDay = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE),
                todayDayFlag = dayFlag(cal),
                currentWifiSsid = currentWifiSsid(context),
                // WEBSITE/SECTION NON sono raggiungibili dal backup: senza
                // AccessibilityService non c'è l'albero dei nodi per rilevare
                // URL o sezioni in-app. È un'asimmetria INTENZIONALE: quando
                // l'accessibility è morto, il blocco siti/sezioni è sospeso.
                // TODO(health-banner): superficiare "blocco website/sezioni in
                // pausa" all'utente quando l'AccessibilityService è giù (UI
                // fuori scope qui).
                websiteScopeDomain = null,
                sectionWireId = null,
            ),
        )

        when (decision) {
            is BlockDecision.Block -> when (decision.reason) {
                BlockReason.FOCUS_MODE -> {
                    if (currentlyBlockingPackage != pkg) {
                        currentlyBlockingPackage = pkg
                        val appLabel = getAppLabel(pkg)
                        Log.w(TAG, ">>> [BACKUP] BLOCKING $pkg (focus)")
                        onFocusBlock(pkg, appLabel)
                        try {
                            NativeDatabase.insertBlockSession(context, pkg, System.currentTimeMillis())
                            NativeDatabase.insertRestrictedAccessEvent(
                                context,
                                pkg,
                                eventType = 0, // TRIGGERED
                                restrictionType = 4, // FOCUS_MODE
                                timestamp = System.currentTimeMillis(),
                            )
                        } catch (_: Exception) {}
                    }
                    return
                }

                BlockReason.USAGE_LIMIT -> {
                    if (currentlyBlockingPackage != pkg) {
                        currentlyBlockingPackage = pkg
                        val appLabel = getAppLabel(pkg)
                        Log.w(TAG, ">>> [BACKUP] BLOCKING $pkg (daily limit " +
                            "${decision.todayMs / 60_000}/${limitMinutes}min)")
                        onLimitBlock(pkg, appLabel, limitMinutes, decision.todayMs)
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

                else -> { // APP_BLOCKED (FOCUS/USAGE_LIMIT gestiti sopra; WEBSITE/SECTION irraggiungibili)
                    val profile = profiles.firstOrNull { it.id == decision.profileId }
                    if (currentlyBlockingPackage != pkg && profile != null) {
                        currentlyBlockingPackage = pkg
                        val appLabel = getAppLabel(pkg)
                        Log.w(TAG, ">>> [BACKUP] BLOCKING $pkg ($appLabel) by profile '${profile.title}'")
                        onBlock(pkg, appLabel, profile, decision.relation)
                        try {
                            NativeDatabase.insertBlockSession(context, pkg, System.currentTimeMillis())
                        } catch (_: Exception) {}
                    }
                    return
                }
            }

            is BlockDecision.Allow -> {
                // L'evaluator collassa "bypass attivo" e "nessun blocco" in
                // Allow. Ri-leggiamo isBypassed(pkg) per preservare il tracking
                // del bypass per-app (auto-revoke all'uscita), come prima.
                if (OverlayManager.isBypassed(pkg)) {
                    lastBypassedForegroundPkg = pkg
                }
                if (currentlyBlockingPackage != null) {
                    Log.d(TAG, "<<< [BACKUP] UNBLOCKING (switched to $pkg)")
                    currentlyBlockingPackage = null
                    onUnblock()
                }
                return
            }
        }
    }

    /// Bit del giorno corrente (allineato a [BlockPolicyEvaluator] / DayFlags).
    private fun dayFlag(cal: Calendar): Int = when (cal.get(Calendar.DAY_OF_WEEK)) {
        Calendar.MONDAY -> 1
        Calendar.TUESDAY -> 2
        Calendar.WEDNESDAY -> 4
        Calendar.THURSDAY -> 8
        Calendar.FRIDAY -> 16
        Calendar.SATURDAY -> 32
        Calendar.SUNDAY -> 64
        else -> 0
    }

    private fun getAppLabel(packageName: String): String = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        packageName
    }
}
