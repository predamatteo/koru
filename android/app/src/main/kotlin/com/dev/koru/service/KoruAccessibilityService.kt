package com.dev.koru.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
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
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.db.NativeWebsiteRule
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig
import com.dev.koru.strictmode.StrictModeEnforcer
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.atomic.AtomicReference

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
/// Snapshot atomico dello stato profili caricato dal DB. Il foreground thread
/// di AccessibilityService scrive (via [KoruAccessibilityService.loadProfiles])
/// mentre `onAccessibilityEvent` può girare su thread diversi del binder
/// callback; sostituire un riferimento atomico (publish-via-AtomicReference)
/// è strettamente safer di `profiles.clear() + put()` (che durante il refresh
/// presentava una finestra temporale con dati parziali al lettore).
data class ProfilesSnapshot(
    val profiles: List<NativeProfile>,
    val profileApps: Map<Int, List<NativeAppRelation>>,
    val websiteRulesCache: Map<Int, List<NativeWebsiteRule>>,
    val profileIntervals: Map<Int, List<NativeInterval>>,
    val profileWifis: Map<Int, Set<String>>,
) {
    companion object {
        val EMPTY = ProfilesSnapshot(
            emptyList(),
            emptyMap(),
            emptyMap(),
            emptyMap(),
            emptyMap(),
        )
    }
}

class KoruAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "KoruAccessibility"
        const val ACTION_GO_HOME = "com.dev.koru.ACTION_GO_HOME"
        const val ACTION_RELOAD_PROFILES = "com.dev.koru.ACTION_RELOAD_PROFILES"

        /// Profile typeCombinations bit per "time interval enabled".
        /// Allineato a [ProfileType.time] in lib/core/constants/profile_types.dart.
        const val PROFILE_TYPE_TIME = 1

        /// Restriction type log su `restricted_access_events`: nuovo valore per
        /// gli eventi BYPASS_EXPIRED (l'utente è stato ri-prompted dopo che il
        /// TTL di un bypass è scaduto mentre era ancora dentro l'app).
        /// Allineato ai valori usati altrove: 0=APP, 1=SECTION, 2=WEBSITE,
        /// 3=USAGE_LIMIT, 4=FOCUS_MODE. Riserviamo 5 per BYPASS_EXPIRED.
        const val RESTRICTION_TYPE_BYPASS_EXPIRED = 5

        /// Set di package "noti" come browser: usato per popolare
        /// dinamicamente `serviceInfo.packageNames` così l'AccessibilityService
        /// riceve eventi solo dalle app interessanti (vedi `loadProfiles`).
        /// Allineato a `BrowserConfigLoader` per copertura ma indipendente:
        /// se il JSON dei config browser non è ancora caricato all'avvio,
        /// non vogliamo perdere eventi sui browser più comuni.
        val KNOWN_BROWSERS: Set<String> = setOf(
            "com.android.chrome",
            "com.chrome.beta",
            "com.chrome.dev",
            "com.chrome.canary",
            "com.brave.browser",
            "org.mozilla.firefox",
            "org.mozilla.firefox_beta",
            "com.microsoft.emmx",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
            "com.opera.mini.native",
            "com.duckduckgo.mobile.android",
            "com.vivaldi.browser",
        )

        /// Set di package "settings" (system settings + OEM): usato sia da
        /// StrictModeEnforcer sia per popolare `serviceInfo.packageNames`
        /// così possiamo intercettare il blocco "settings" anche quando
        /// l'utente apre l'app di sistema. Allineato (ma non condiviso
        /// direttamente per evitare coupling) con
        /// `StrictModeEnforcer.SETTINGS_PACKAGES`.
        val SETTINGS_PACKAGES: Set<String> = setOf(
            "com.android.settings",
            "com.samsung.android.app.routines",
            "com.miui.securitycenter",
            "com.coloros.safecenter",
            "com.coloros.oplusphonemanager",
            "com.huawei.systemmanager",
            "com.oneplus.security",
            "com.oplus.settings",
        )

        @Volatile
        var instance: KoruAccessibilityService? = null
            private set

        /// Timestamp (epoch ms) fino a cui MainActivity.onNewIntent deve
        /// IGNORARE l'HOME intent invece di forzare la navigazione Flutter
        /// a `/launcher`. Settato dal servizio prima di ogni HOME triggrato
        /// per blocking; senza questa soppressione l'utente perde la pagina
        /// su cui si trovava nel launcher (perche' ogni HOME intent reset-
        /// avva GoRouter alla prima schermata via NavigationMethodChannel).
        @Volatile
        var suppressLauncherNavigationUntilMs: Long = 0L

        fun performGoHomeAction() { instance?.performGoHomeForBlock() }
        fun triggerReload() { instance?.forceReloadProfiles() }
    }

    /// Riporta l'utente fuori dall'app bloccata. Due strategie:
    ///
    /// **BACK** (default, [forceHome] = false) — usato per il blocco
    /// AUTOMATICO (l'utente apre l'app fresh dal launcher). Ripristina
    /// lo stato precedente: se l'utente ha tappato l'icona dalla pagina
    /// 3 del launcher, BACK lo riporta lì invece che alla pagina 1 (HOME).
    /// E' il comportamento naturale di Android.
    ///
    /// **HOME** ([forceHome] = true) — usato per il click ESPLICITO
    /// dell'utente su "Don't open $appLabel" / "Close $appLabel"
    /// sull'overlay (callback onReturnHome). Quando l'utente clicca
    /// quel bottone ha intento univoco: uscire dall'app, indipendente-
    /// mente dallo stack interno. BACK qui sarebbe sbagliato perche'
    /// se l'app ha activity stack interno (es. Instagram con storia
    /// aperta sopra la feed), un singolo BACK chiude solo la storia,
    /// non IG → l'utente vede l'overlay sparire e IG ancora in
    /// foreground. Bug osservato: clicchi "Close instagram" dalla storia
    /// → viene chiusa la storia ma IG no.
    ///
    /// **Fallback HOME-after-BACK**: dopo BACK schedula un re-check a
    /// 600ms; se [blockedPackage] è ancora in foreground (sintomo:
    /// YouTube mini-player o Instagram inner stack ha "ingoiato" il
    /// BACK senza chiudere il task), forza HOME via Intent. Bug
    /// osservato: link YouTube tappato da WhatsApp → blocco → BACK →
    /// YouTube riduce a mini-player → AccessibilityEvent ri-spara per
    /// YT → re-blocco → BACK → loop infinito tra WA e overlay con il
    /// timer che si resetta a ogni show.
    ///
    /// In entrambi i casi settiamo `suppressLauncherNavigationUntilMs`
    /// per preservare la sub-pagina del launcher Flutter: se Koru e'
    /// il default launcher, MainActivity ricevera' un HOME intent
    /// (direttamente o via il fallback BACK→HOME) e senza la finestra
    /// di soppressione `onNewIntent` chiamerebbe `goToLauncher()`
    /// resettando GoRouter alla pagina launcher base.
    fun performGoHomeForBlock(forceHome: Boolean = false, blockedPackage: String? = null) {
        val until = System.currentTimeMillis() + 1_500L
        suppressLauncherNavigationUntilMs = until

        // Se forceHome (path HOME diretto, es. tap "Don't open"), cancella
        // qualunque fallback BACK→HOME pending: stiamo gia' facendo HOME,
        // un secondo HOME 600ms dopo sarebbe inutile e potrebbe interferire
        // con la navigazione utente nel launcher.
        if (forceHome) {
            pendingBackFallbacks.values.forEach { mainHandler.removeCallbacks(it) }
            pendingBackFallbacks.clear()
        }

        if (!forceHome) {
            Log.d(TAG, "GoHomeForBlock: BACK pkg=$blockedPackage suppressUntilMs=$until")
            val backOk = try {
                performGlobalAction(GLOBAL_ACTION_BACK)
            } catch (e: Exception) {
                Log.w(TAG, "GLOBAL_ACTION_BACK threw, will fallback to HOME", e)
                false
            }
            if (backOk) {
                blockedPackage?.let { scheduleBackFallbackHome(it) }
                return
            }
            Log.w(TAG, "BACK refused, falling back to HOME intent")
        } else {
            Log.d(TAG, "GoHomeForBlock: HOME (forced) + suppressUntilMs=$until")
        }

        // HOME via Intent: va al default launcher senza forzare Koru.
        // Chiude effettivamente il task dell'app target indipendentemente
        // dal suo stack interno (a differenza di BACK).
        goToHomeViaIntent()
    }

    private fun goToHomeViaIntent() {
        try {
            val home = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(home)
        } catch (e: Exception) {
            Log.e(TAG, "HOME intent failed", e)
        }
    }

    /// Schedulato dopo un GLOBAL_ACTION_BACK riuscito: a 600ms verifica
    /// che il pkg target NON sia più in foreground. Se invece e' ancora
    /// li, BACK e' stato "ingoiato" da uno stack interno (mini-player YT,
    /// inner activity IG, deep-link trampoline) → forziamo HOME.
    ///
    /// Usiamo [ForegroundDetector] (UsageStats) come signal authoritative
    /// invece di [lastForegroundPackage]: quest'ultimo non si aggiorna
    /// mentre il foreground e' un pkg "skip" (launcher/systemui), quindi
    /// se BACK ha funzionato e l'utente e' nel launcher avremmo
    /// `lastForegroundPackage == pkg` (falso positivo) e re-faremmo
    /// HOME inutilmente.
    private val pendingBackFallbacks = mutableMapOf<String, Runnable>()
    private fun scheduleBackFallbackHome(pkg: String) {
        pendingBackFallbacks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }
        val r = object : Runnable {
            override fun run() {
                // Service hygiene: il runnable potrebbe essere stato
                // schedulato prima che onDestroy nullasse `instance`. Senza
                // questo guard rischiamo NPE/IllegalState chiamando metodi
                // su un service smontato (es. applicationContext).
                if (instance != this@KoruAccessibilityService) return
                pendingBackFallbacks.remove(pkg)
                val fg = ForegroundDetector.detect(applicationContext)?.primaryPackage
                if (fg != pkg) {
                    Log.d(TAG, "BACK fallback: $pkg already left (foreground=$fg)")
                    return
                }
                Log.w(TAG, "BACK fallback: $pkg still foreground after 600ms — forcing HOME")
                suppressLauncherNavigationUntilMs = System.currentTimeMillis() + 1_500L
                goToHomeViaIntent()
            }
        }
        pendingBackFallbacks[pkg] = r
        mainHandler.postDelayed(r, 600L)
    }

    /// Snapshot atomico letto da `onAccessibilityEvent` e dai check workflow.
    /// Sostituire il riferimento con un nuovo oggetto immutabile garantisce
    /// publish atomico fra thread (foreground service loop vs binder callback)
    /// senza lock e senza finestra temporale di stato parziale.
    private val profilesSnapshot = AtomicReference(ProfilesSnapshot.EMPTY)
    @Volatile
    private var lastProfileLoadTime = 0L
    @Volatile
    private var currentlyBlockingPackage: String? = null
    @Volatile
    private var lastForegroundPackage: String? = null

    /// Pkg dell'ultima app bypassata che era effettivamente in foreground.
    /// Usato per implementare l'auto-revoke del bypass quando l'utente esce
    /// dall'app: se il foreground cambia verso un pkg diverso (launcher,
    /// systemui o un'altra app), il bypass del pkg precedente viene azzerato.
    /// Il prossimo rientro nell'app ri-mostra l'overlay con countdown invece
    /// di sfruttare il timer residuo, allineando il comportamento al pattern
    /// "ogni session richiede un'intenzione esplicita" che si aspettano gli
    /// utenti dei limiti temporali non-strict.
    @Volatile
    private var lastBypassedActiveForeground: String? = null

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

    @Volatile
    private var actionReceiver: BroadcastReceiver? = null
    @Volatile
    private var inAppDetector: InAppContentDetector? = null
    @Volatile
    private var lastSectionEventTime = 0L
    @Volatile
    private var lastDetectedSectionWireId: String? = null

    @Volatile
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
    @Volatile
    private var lastBrowserContentCheckMs = 0L
    @Volatile
    private var lastBrowserContentPkg: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        inAppDetector = InAppContentDetector(applicationContext)
        overlayManager = OverlayManager(applicationContext).apply {
            onReturnHome = { forceHome ->
                // Tap esplicito dall'overlay: il flag `forceHome` decide
                // se forzare HOME (Intent) o tentare BACK prima con
                // fallback HOME. La policy è scelta in OverlayManager
                // in base alla BlockReason: APP_BLOCKED → BACK (preserva
                // sub-pagina launcher), BYPASS_EXPIRED/USAGE_LIMIT/SECTION
                // → HOME forzato (l'utente vuole uscire univocamente
                // dall'app con stack interno tipo Instagram-storia).
                performGoHomeForBlock(forceHome = forceHome)
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
                // markBypassed(pkg, durationMs). Resterà valido per la durata
                // scelta MENTRE l'app è in foreground; se l'utente esce e
                // rientra, `onAccessibilityEvent` revoca il bypass tramite
                // [OverlayManager.clearBypass] (vedi
                // [lastBypassedActiveForeground]) → al rientro l'overlay
                // con countdown ricompare. Una sessione = una scelta.
                Log.i(TAG, "BYPASS-GRANTED: $pkg for ${durationMs / 60_000}min (TTL until ${System.currentTimeMillis() + durationMs})")
                try {
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        pkg,
                        eventType = 1, // SKIPPED
                        restrictionType = 0, // APP
                        timestamp = System.currentTimeMillis(),
                    )
                } catch (_: Exception) {}
                // Progressive friction: incrementa il counter solo quando il
                // bypass discende da un blocco USAGE_LIMIT (entry o expired)
                // su un'app NON strict. Bypass su APP_BLOCKED/profili/sezioni
                // non alimentano la friction del daily limit (sono use case
                // diversi). Strict mode è gestito a monte (no "Open anyway"
                // sull'overlay), quindi qui non dovrebbe arrivare — defensive.
                val reason = overlayManager?.currentReason()
                if (reason == BlockReason.USAGE_LIMIT ||
                    reason == BlockReason.BYPASS_EXPIRED
                ) {
                    val entry = AppUsageLimitsStore.entryFor(applicationContext, pkg)
                    if (entry != null && !entry.strict) {
                        val n = BypassCountStore.increment(applicationContext, pkg)
                        Log.i(TAG, "Daily-limit bypass count for $pkg → $n")
                    }
                }
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
                    ACTION_GO_HOME -> performGoHomeForBlock()
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

        // Snapshot atomico in cima all'event: tutti i check successivi
        // useranno questa view consistente, anche se loadProfiles() viene
        // richiamato concorrentemente dal Refresh receiver. Se in un branch
        // facciamo un reload, ri-leggiamo lo snapshot dopo (variabile
        // `freshSnapshot`) — entrambi sono `val` cosi' la promise di
        // consistenza per la durata di ogni check resta valida.

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
            // Recupera snapshot aggiornato dopo eventuale reload.
            val freshSnapshot = profilesSnapshot.get()
            withRootInActiveWindow { root ->
                if (root == null) {
                    Log.w(TAG, "BROWSER ${event.eventType}: rootInActiveWindow null for $pkg")
                } else {
                    checkWebsiteBlocking(pkg, root, freshSnapshot)
                }
            }
            return
        }

        // TYPE_WINDOWS_CHANGED: cambio tab nel browser, nuova finestra, ecc.
        // Trattiamolo come uno state change (ri-check app + website).
        val isWindowChange = event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
        if (!isWindowChange) return

        // Auto-revoke del bypass on app exit. Quando l'ultimo pkg bypassato in
        // foreground non corrisponde al pkg dell'evento corrente, significa che
        // l'utente sta passando ad un'altra app (o al launcher): il bypass
        // residuo va azzerato così che il prossimo rientro nell'app mostri di
        // nuovo l'overlay con countdown invece di sfruttare il timer ancora
        // attivo. Comportamento allineato a Opal/ScreenZen: ogni "session"
        // richiede una scelta esplicita.
        //
        // Authoritative check via UsageStats. Eventi accessibility per pkg
        // diverso possono essere ghost (transizione di un'app uscente, o
        // framework events come "android"/packageName mentre il nostro overlay
        // si monta sopra l'app stessa). UsageStats riporta il foreground reale,
        // che è la verità: se differisce ancora dal prevBypassed siamo davanti
        // ad un cambio reale → revoca; se è ancora prevBypassed l'evento è un
        // ghost e lasciamo il bypass intatto.
        //
        // Quando UsageStats non risponde (raro: permission revoke runtime,
        // boot prematuro) preferiamo conservare il bypass: una mancata revoca
        // è meno invasiva di una revoca falsa che farebbe ri-comparire
        // l'overlay nel mezzo della sessione legittima dell'utente.
        val prevBypassed = lastBypassedActiveForeground
        if (prevBypassed != null && pkg != prevBypassed) {
            val realFg = ForegroundDetector.detect(applicationContext)?.primaryPackage
            Log.i(TAG, "BYPASS-REVOKE-CHECK: prev=$prevBypassed event=$pkg realFg=$realFg")
            if (realFg != null && realFg != prevBypassed) {
                Log.i(TAG, "BYPASS-REVOKE-DO: user left $prevBypassed (real fg=$realFg, event=$pkg)")
                OverlayManager.clearBypass(prevBypassed)
                pendingBypassExpiryChecks.remove(prevBypassed)
                    ?.let { mainHandler.removeCallbacks(it) }
                lastBypassedActiveForeground = null
            } else {
                Log.i(TAG, "BYPASS-REVOKE-SKIP: $prevBypassed still real fg (event=$pkg, realFg=$realFg)")
            }
        }

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
        val freshSnapshot = profilesSnapshot.get()

        val blockedByApp = checkAppBlocking(pkg, freshSnapshot)
        if (blockedByApp) return

        // In-app content blocking (Instagram Reels/Stories/Explore, YouTube Shorts)
        val detector = inAppDetector
        if (detector != null && detector.supports(pkg)) {
            var handled = false
            withRootInActiveWindow { root ->
                if (root != null && checkInAppContentBlocking(pkg, root, freshSnapshot)) {
                    handled = true
                }
            }
            if (handled) return
        }

        if (BrowserConfigLoader.isBrowser(applicationContext, pkg)) {
            withRootInActiveWindow { root ->
                if (root != null) checkWebsiteBlocking(pkg, root, freshSnapshot)
            }
        }
    }

    /// Helper centralizzato per ottenere il root node, eseguire una callback
    /// e poi recyclare il nodo su API < 33 (su API 33+ il recycle e' no-op
    /// safe). Necessario per evitare leak di AccessibilityNodeInfo nel buffer
    /// del binder accessibility — sintomi: log "Suspicious node" e fps drop
    /// dopo qualche minuto di attività.
    private inline fun withRootInActiveWindow(block: (AccessibilityNodeInfo?) -> Unit) {
        val root = try { rootInActiveWindow } catch (_: Exception) { null }
        try {
            block(root)
        } finally {
            if (root != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                try { root.recycle() } catch (_: Throwable) {}
            }
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
                // Service hygiene: skip se il service e' stato distrutto.
                if (instance != this@KoruAccessibilityService) return
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
                // Service hygiene: skip se il service e' stato distrutto.
                if (instance != this@KoruAccessibilityService) return
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
                checkAppBlocking(pkg, profilesSnapshot.get())
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
        val snapshot = profilesSnapshot.get()
        // Cerchiamo una relation app→profilo per ereditare la palette
        // dell'overlay config; in assenza usiamo DEFAULT.
        val relation = snapshot.profileApps.values.asSequence().flatten()
            .firstOrNull { it.packageName == pkg }
        val baseConfig = OverlayConfig.fromJsonString(relation?.overlayConfigJson)
        val matchingProfile = snapshot.profiles.firstOrNull { p ->
            snapshot.profileApps[p.id]?.any { it.packageName == pkg } == true
        }
        // Se l'estensione discende da un USAGE_LIMIT (l'utente aveva
        // bypassato un cap giornaliero), applichiamo la stessa policy
        // progressiva del blocco entry: durate decrescenti dopo soglia,
        // niente pausa. Per limit strict comunque non arriviamo qui (no
        // bypass possibile a monte).
        val limitEntry = AppUsageLimitsStore.entryFor(applicationContext, pkg)
        val (config, policy) = if (limitEntry != null && !limitEntry.strict) {
            // buildUsageLimitOverlay riceve `baseConfig` cosi' l'OverlayConfig
            // ritornato eredita la palette / countdown / shake personalizzati
            // dall'utente per quella relation. Senza questo merge l'estensione
            // perdeva sempre i colori utente e usava OverlayConfig.DEFAULT.
            val (cfg, p) = OverlayPolicies.buildUsageLimitOverlay(
                applicationContext, pkg, baseConfig = baseConfig, isStrict = false,
            )
            cfg to p
        } else {
            baseConfig to BypassPolicy()
        }
        mainHandler.post {
            overlayManager?.show(
                packageName = pkg,
                appLabel = appLabel,
                profileTitle = matchingProfile?.title ?: "Koru",
                reason = BlockReason.BYPASS_EXPIRED,
                config = config,
                profileEmoji = matchingProfile?.emoji,
                bypassPolicy = policy,
            )
        }
        try {
            NativeDatabase.insertRestrictedAccessEvent(
                applicationContext,
                pkg,
                eventType = 0, // TRIGGERED
                // Dedicato BYPASS_EXPIRED: discrimina nel log analytics da un
                // normale APP block (era loggato come restrictionType=0).
                restrictionType = RESTRICTION_TYPE_BYPASS_EXPIRED,
                timestamp = System.currentTimeMillis(),
            )
        } catch (_: Exception) {}
    }

    /**
     * Ritorna true se ha bloccato l'app (overlay mostrato + HOME).
     */
    private fun checkAppBlocking(
        packageName: String,
        snapshot: ProfilesSnapshot = profilesSnapshot.get(),
    ): Boolean {
        // Bypass timed: l'utente ha scelto una durata esplicita dal duration
        // picker. Finché quella durata non scade, non mostriamo l'overlay.
        // Tracciamo il pkg come "bypassato e in foreground" per abilitare
        // l'auto-revoke al prossimo cambio di foreground (vedi
        // [onAccessibilityEvent]).
        if (OverlayManager.isBypassed(packageName)) {
            Log.i(TAG, "BYPASS-ACTIVE: $packageName in foreground, tracking for auto-revoke")
            lastBypassedActiveForeground = packageName
            return false
        }

        // GHOST-EVENT GUARD. TYPE_WINDOW_STATE_CHANGED / TYPE_WINDOWS_CHANGED
        // possono essere emessi anche per un'app che sta PERDENDO il
        // foreground durante una transizione (la finestra che scompare
        // genera un evento "state changed"). Senza guardia il flow vicioso e':
        //
        //  1. Utente in IG (bloccato dal profilo) → tocca notifica WhatsApp.
        //  2. Durante la transizione arriva un evento per IG mentre WA sta
        //     gia' diventando foreground reale.
        //  3. checkAppBlocking(IG) → BLOCK → overlay + GLOBAL_ACTION_BACK.
        //  4. WA NON e' monitorata (non in nessun profilo → fuori dal
        //     watched set di applyDynamicPackageFilter), quindi nessun
        //     evento per WA arriva: `currentlyBlockingPackage` non viene
        //     resettato e l'overlay resta sopra WA.
        //  5. Il BACK pending colpisce WA (GLOBAL_ACTION_BACK e' globale
        //     sul foreground reale al momento del dispatch, e WA e' gia'
        //     li'). WA chiude → torna IG (stack precedente) → nuovo evento
        //     IG → BLOCK #2 → overlay #2. L'utente preme "Don't open" due
        //     volte e finisce sul launcher senza l'app che voleva aprire.
        //
        // Verifichiamo via UsageStats (authoritative su chi e' realmente
        // foreground) che pkg sia il foreground reale corrente. Se il
        // foreground reale e' un'altra app non-skip, l'evento per pkg e'
        // un ghost di uscita → no block. Foreground=skipPackages
        // (launcher/systemui) o null → procediamo: UsageStats puo' laggare
        // e in dubbio bloccare e' piu' sicuro che non bloccare (es. evento
        // di apertura legittimo subito dopo HOME, dove ACTIVITY_RESUMED
        // del pkg target non e' ancora stato indicizzato).
        val foregroundDetected = ForegroundDetector
            .detect(applicationContext)?.primaryPackage
        if (foregroundDetected != null &&
            foregroundDetected != packageName &&
            !skipPackages.contains(foregroundDetected)
        ) {
            Log.d(
                TAG,
                "checkAppBlocking: pkg=$packageName but real foreground=" +
                    "$foregroundDetected (ghost transition event) — skip",
            )
            return false
        }

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
            // FOCUS_MODE: forceHome=true. La user-intent del Pomodoro / focus
            // session è uscire dall'app, non navigare lo stack interno.
            // BACK su un'app con activity nested chiuderebbe solo l'inner
            // activity e l'app target resterebbe in foreground.
            performGoHomeForBlock(forceHome = true, blockedPackage = packageName)
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

        // Daily usage limit FIRST: deve vincere sul profile block quando il
        // cap e' superato. Bug pre-fix: profile loop girava per primo, quindi
        // un'app bloccata SIA da profilo SIA da daily limit (con cap gia'
        // sforato) mostrava APP_BLOCKED + BypassPolicy() di default (countdown
        // ~9s + "Open anyway") invece del USAGE_LIMIT overlay strict/progressive.
        // L'utente attendeva il countdown e poteva aprire l'app nonostante il
        // tempo fosse gia' finito (e in strict mode il bypass non dovrebbe
        // essere consentito affatto). Lo spostamento del check qui fa sì
        // che il USAGE_LIMIT overlay prevalga e il messaging rifletta la
        // realtà. La schedulazione del re-check (caso cap non ancora
        // raggiunto) resta DOPO il profile loop.
        val limitEntry = AppUsageLimitsStore.entryFor(applicationContext, packageName)
        val limitMinutes = limitEntry?.minutes ?: 0
        val limitTodayMs = if (limitMinutes > 0) {
            UsageCounter.todayForegroundMs(applicationContext, packageName)
        } else 0L
        val limitMs = limitMinutes * 60_000L
        if (limitMinutes > 0 && limitTodayMs >= limitMs) {
            val isStrict = limitEntry?.strict ?: true
            Log.w(TAG, ">>> BLOCKING APP (daily limit, strict=$isStrict): $packageName " +
                "${limitTodayMs / 60_000}min used, cap=${limitMinutes}min")
            currentlyBlockingPackage = packageName
            cancelLimitCheck(packageName)
            val appLabel = getAppLabel(packageName)
            val limitRelation = snapshot.profileApps.values.asSequence()
                .flatten()
                .firstOrNull { it.packageName == packageName }
            val limitBaseConfig = OverlayConfig.fromJsonString(limitRelation?.overlayConfigJson)
            val (overlayConfig, policy) = OverlayPolicies.buildUsageLimitOverlay(
                applicationContext,
                packageName,
                baseConfig = limitBaseConfig,
                isStrict = isStrict,
            )
            mainHandler.post {
                overlayManager?.show(
                    packageName = packageName,
                    appLabel = appLabel,
                    profileTitle = if (isStrict) "Daily limit · strict" else "Daily limit",
                    reason = BlockReason.USAGE_LIMIT,
                    config = overlayConfig,
                    profileEmoji = "⏳",
                    bypassPolicy = policy,
                )
            }
            performGoHomeForBlock(blockedPackage = packageName)
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
        }

        for (profile in snapshot.profiles) {
            if (!isProfileActiveNow(profile, snapshot)) continue

            val apps = snapshot.profileApps[profile.id] ?: emptyList()
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
                performGoHomeForBlock(blockedPackage = packageName)
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

        // Daily limit esiste ma cap non ancora raggiunto: pianifica un
        // re-check fra (limitMs - limitTodayMs) ms cosi' se l'utente resta
        // dentro l'app il blocco scatta nel momento in cui il cap viene
        // toccato, non solo al prossimo cambio di window state. Senza
        // questo timer, un utente che entra a 28' e resta dentro continua
        // a usare l'app oltre i 30' senza che nulla lo fermi (bug osservato
        // su Instagram). Il caso "cap gia' superato" e' gestito sopra prima
        // del profile loop.
        if (limitMinutes > 0) {
            scheduleLimitCheck(packageName, limitMs - limitTodayMs)
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
        snapshot: ProfilesSnapshot = profilesSnapshot.get(),
    ): Boolean {
        val detected = inAppDetector?.detect(packageName, root) ?: return false

        // Debounce: avoid firing for the same detection within 1s
        val now = System.currentTimeMillis()
        if (detected.wireId == lastDetectedSectionWireId && now - lastSectionEventTime < 1_000) {
            return false
        }
        lastDetectedSectionWireId = detected.wireId
        lastSectionEventTime = now

        for (profile in snapshot.profiles) {
            if (!isProfileActiveNow(profile, snapshot)) continue
            val apps = snapshot.profileApps[profile.id] ?: continue
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
            // SECTION_BLOCKED: forceHome=true. Bloccare una "sezione"
            // dentro un'app (es. Reels, Shorts) ha senso solo se l'app
            // viene effettivamente chiusa. BACK chiuderebbe solo la
            // sub-activity (es. il viewer Reels) e l'utente resterebbe
            // sulla home dell'app, libero di tornare immediatamente
            // sulla sezione bloccata.
            performGoHomeForBlock(forceHome = true, blockedPackage = packageName)
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

    private fun checkWebsiteBlocking(
        packageName: String,
        rootNode: AccessibilityNodeInfo,
        snapshot: ProfilesSnapshot = profilesSnapshot.get(),
    ) {
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

        if (snapshot.websiteRulesCache.isEmpty()) {
            Log.w(TAG, "  → websiteRulesCache is EMPTY")
            return
        }

        for ((profileId, rules) in snapshot.websiteRulesCache) {
            // Gating temporale: blocca i domini solo se il profilo è attivo
            // ORA (time interval, dayFlags, pausa, onUntil, wifi). Senza questo
            // il blocco domini restava SEMPRE attivo ignorando lo schedule del
            // profilo — stesso check di checkAppBlocking (~915) e del section
            // blocking (~996), che invece lo applicano correttamente.
            val matchedProfile = snapshot.profiles.firstOrNull { it.id == profileId }
            if (matchedProfile == null || !isProfileActiveNow(matchedProfile, snapshot)) continue
            Log.d(TAG, "  profile $profileId has ${rules.size} rules: ${rules.map { "${it.name}(type=${it.blockingType},any=${it.isAnywhereInUrl})" }}")
            if (WebsiteMatcher.matchesAny(rules, detected.fullUrl, detected.domain)) {
                Log.w(TAG, ">>> BLOCKING SITE: ${detected.domain} by profile $profileId")
                val profileTitle = matchedProfile.title
                // Setta currentlyBlockingPackage cosi' quando l'utente cambia
                // tab a un sito non bloccato (o naviga via dal browser),
                // il path "no profile blocks this pkg" di checkAppBlocking
                // smonta correttamente l'overlay (era un bug: dopo blocco
                // website l'overlay restava montato anche su tab pulita).
                currentlyBlockingPackage = packageName
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = detected.domain,
                        profileTitle = profileTitle,
                        reason = BlockReason.WEBSITE_BLOCKED,
                        profileEmoji = matchedProfile.emoji,
                    )
                }
                // WEBSITE_BLOCKED: forceHome=true. L'utente sta navigando in
                // un browser; BACK porta alla pagina precedente del browser,
                // che spesso è la stessa scheda. La user-intent "non aprire
                // questo sito" si soddisfa solo chiudendo il browser fino
                // a fuori — HOME è il fix per gli stessi pattern di IG/YT.
                performGoHomeForBlock(forceHome = true, blockedPackage = packageName)
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

    private fun isProfileActiveNow(
        profile: NativeProfile,
        snapshot: ProfilesSnapshot = profilesSnapshot.get(),
    ): Boolean {
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
        val intervals = snapshot.profileIntervals[profile.id] ?: emptyList()
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
        val wifiSet = snapshot.profileWifis[profile.id]
        if (wifiSet != null && wifiSet.isNotEmpty()) {
            val current = getCurrentWifiSsid()
            if (current == null || !wifiSet.contains(current)) return false
        }
        return true
    }

    private fun loadProfiles() {
        try {
            // Niente NativeDatabase.close() qui: l'open è idempotente e
            // chiudere mentre un altro thread (LockRunnable, MainActivity
            // bg-thread) sta leggendo causa SQLite IOError sul cursore in
            // corso. La connection rimane aperta per tutta la vita del
            // service e viene chiusa solo in onDestroy.
            val newProfiles = NativeDatabase.getEnabledProfiles(applicationContext)
            val newProfileApps = mutableMapOf<Int, List<NativeAppRelation>>()
            val intervalsByProfile = mutableMapOf<Int, List<NativeInterval>>()
            for (p in newProfiles) {
                newProfileApps[p.id] = NativeDatabase.getAppRelationsForProfile(applicationContext, p.id)
                intervalsByProfile[p.id] = NativeDatabase.getIntervalsForProfile(applicationContext, p.id)
            }
            val newRules = NativeDatabase.getAllWebsiteRulesForEnabledProfiles(applicationContext)
            val newWifis = NativeDatabase.getWifiSsidsByProfile(applicationContext)

            // Costruisco snapshot immutabile LOCALE e poi swap atomico.
            // Cosi' eventuali letture concorrenti vedono o il vecchio o il
            // nuovo snapshot, mai uno stato parziale (es. profili nuovi ma
            // profileApps ancora del vecchio set, finestra esistente nel
            // pattern precedente di clear()+put()).
            val snapshot = ProfilesSnapshot(
                profiles = newProfiles,
                profileApps = newProfileApps.toMap(),
                websiteRulesCache = newRules,
                profileIntervals = intervalsByProfile.toMap(),
                profileWifis = newWifis,
            )
            profilesSnapshot.set(snapshot)
            lastProfileLoadTime = System.currentTimeMillis()
            Log.d(TAG, "Loaded ${snapshot.profiles.size} profiles, ${snapshot.profileWifis.size} with wifi constraints, " +
                "${snapshot.profileIntervals.values.sumOf { it.size }} intervals")

            // Filtro dinamico per AccessibilityService: limita gli eventi
            // ricevuti al solo set di package che effettivamente ci interessa
            // (apps configurate nei profili + browser noti + settings).
            // Riduce significativamente la pressione sul binder accessibility
            // su sistemi con tante app installate. Cambiare `packageNames` su
            // `serviceInfo` deve essere fatto ricreando l'AccessibilityServiceInfo
            // — settare in-place su quello restituito da `getServiceInfo` non
            // sempre prende effetto.
            applyDynamicPackageFilter(snapshot)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading profiles: ${e.message}")
            profilesSnapshot.set(ProfilesSnapshot.EMPTY)
        }
    }

    /// Aggiorna `serviceInfo.packageNames` con l'unione di:
    /// - tutti i package referenziati dai profili attivi
    /// - browser noti (per intercettare URL websites)
    /// - settings (per StrictModeEnforcer)
    /// - launcher/systemui (per rilevare quando l'utente esce dall'app
    ///   bypassata → trigger auto-revoke del bypass in onAccessibilityEvent;
    ///   senza questi il servizio NON riceve TYPE_WINDOW_STATE_CHANGED
    ///   quando si torna alla home e il bypass resta attivo indefinitamente)
    ///
    /// Se l'unione e' vuota lasciamo `packageNames = null` (= ricevi da tutti),
    /// altrimenti il servizio non riceverebbe alcun evento prima del primo
    /// profilo configurato.
    @Volatile
    private var lastWatchedPackages: Set<String>? = null

    private fun applyDynamicPackageFilter(snapshot: ProfilesSnapshot) {
        try {
            val profilePackages = snapshot.profileApps.values
                .flatten()
                .map { it.packageName }
                .toSet()
            val watched = profilePackages + KNOWN_BROWSERS + SETTINGS_PACKAGES +
                skipPackages + packageName
            // Skip se il set non e' cambiato: ricreare AccessibilityServiceInfo
            // forza il system_server a re-validare il manifest e re-bindare
            // il service — operazione non gratuita, va evitata se inutile.
            if (watched == lastWatchedPackages) return
            val info = serviceInfo ?: return
            // Modifichiamo in place i soli campi mutabili (packageNames).
            // canRetrieveWindowContent e' read-only sull'oggetto e proviene
            // dal manifest config XML — preservato implicitamente dato che
            // riutilizziamo l'istanza esistente. Creare un nuovo
            // AccessibilityServiceInfo from scratch perderebbe quel flag e
            // il system_server lo ri-validerebbe via meta-data.
            info.packageNames = if (watched.isEmpty()) null else watched.toTypedArray()
            serviceInfo = info
            lastWatchedPackages = watched
        } catch (e: Exception) {
            Log.w(TAG, "applyDynamicPackageFilter failed: ${e.message}")
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
        lastForegroundPackage?.let { checkAppBlocking(it, profilesSnapshot.get()) }
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

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Forward al manager: l'overlay deve potersi riallineare a un cambio
        // di rotazione / dark mode / scale font senza ricreare l'overlay
        // da capo (verrebbe perso lo stato del countdown).
        overlayManager?.onConfigurationChanged()
    }

    override fun onDestroy() {
        instance = null
        actionReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        actionReceiver = null
        pendingBypassExpiryChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingBypassExpiryChecks.clear()
        pendingLimitChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingLimitChecks.clear()
        pendingBackFallbacks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingBackFallbacks.clear()
        lastBypassedActiveForeground = null
        overlayManager?.destroy()
        overlayManager = null
        NativeDatabase.close()
        super.onDestroy()
    }
}
