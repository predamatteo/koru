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
import com.dev.koru.BuildConfig
import com.dev.koru.browser.BrowserConfigLoader
import com.dev.koru.browser.BrowserUrlDetector
import com.dev.koru.browser.WebsiteMatcher
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.contract.BlockingContract
import com.dev.koru.content.InAppContentDetector
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.db.NativeWebsiteRule
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig
import com.dev.koru.strictmode.StrictModeEnforcer
import com.dev.koru.strictmode.StrictModeFailSafe
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

        /// Restriction type log su `restricted_access_events`: valore per gli
        /// eventi BYPASS_EXPIRED (l'utente è stato ri-prompted dopo che il TTL
        /// di un bypass è scaduto mentre era ancora dentro l'app). ARCH-06: i
        /// codici restrictionType (0=APP, 1=SECTION, 2=WEBSITE, 3=USAGE_LIMIT,
        /// 4=FOCUS_MODE, 5=BYPASS_EXPIRED) vivono ora in [BlockingContract].
        /// Alias mantenuto perché referenziato come costante in questo file.
        const val RESTRICTION_TYPE_BYPASS_EXPIRED = BlockingContract.RESTRICTION_TYPE_BYPASS_EXPIRED

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
        /// l'utente apre l'app di sistema. ARCH-06: ora condiviso via
        /// [BlockingContract.SETTINGS_PACKAGES] (era duplicato a mano con
        /// `StrictModeEnforcer`, tenuto allineato solo da un commento).
        val SETTINGS_PACKAGES: Set<String> = BlockingContract.SETTINGS_PACKAGES

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
            onBypassOpen = { pkg, durationMs, domain ->
                // Il bypass è stato registrato in OverlayManager.Companion via
                // markBypassed(pkg, durationMs, domain). domain non-null = blocco
                // website → bypass per-dominio (sblocca solo quel sito, non tutto
                // il browser). Resterà valido per la durata
                // scelta MENTRE l'app è in foreground; se l'utente esce e
                // rientra, `onAccessibilityEvent` revoca il bypass tramite
                // [OverlayManager.clearBypass] (vedi
                // [lastBypassedActiveForeground]) → al rientro l'overlay
                // con countdown ricompare. Una sessione = una scelta.
                Log.i(TAG, "BYPASS-GRANTED: $pkg for ${durationMs / 60_000}min (TTL until ${System.currentTimeMillis() + durationMs})")
                // Traccia SUBITO il pkg come "bypassato e in foreground" così
                // l'auto-revoke all'uscita (onAccessibilityEvent) scatta anche
                // per i limit-bypass, non solo per quelli di profilo. Senza,
                // uscire e rientrare entro la finestra riapriva l'app senza
                // frizione né incremento del contatore, e la frizione
                // progressiva non scalava mai (H1). checkAppBlocking lo
                // riconferma al primo evento; questo chiude la micro-finestra
                // tra il grant e l'evento successivo.
                lastBypassedActiveForeground = pkg
                try {
                    NativeDatabase.insertRestrictedAccessEvent(
                        applicationContext,
                        pkg,
                        eventType = 1, // SKIPPED
                        restrictionType = BlockingContract.RESTRICTION_TYPE_APP,
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
                scheduleBypassExpiryCheck(pkg, durationMs, domain)
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

        // SEC-02: all'avvio del processo di enforcement, se rileviamo la firma
        // del "Clear data con strict armato" (device admin attivo ma store
        // vergine) ri-armiamo lo strict mode a ALL e notifichiamo (fail-secure).
        try {
            StrictModeFailSafe.checkAndReassert(applicationContext)
        } catch (e: Exception) {
            Log.w(TAG, "StrictModeFailSafe check failed: ${e.message}")
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
                // Cancella i timer di scadenza sia per-app (chiave = pkg) sia
                // per-dominio (chiavi `pkg|dominio`), simmetrico a clearBypass:
                // i timer dei siti sono registrati con chiave composita, quindi
                // un remove(pkg) singolo li lascerebbe orfani → showExtension-
                // Prompt fantasma dopo l'uscita dal browser.
                val expiryIt = pendingBypassExpiryChecks.entries.iterator()
                while (expiryIt.hasNext()) {
                    val e = expiryIt.next()
                    if (e.key == prevBypassed || e.key.startsWith("$prevBypassed|")) {
                        mainHandler.removeCallbacks(e.value)
                        expiryIt.remove()
                    }
                }
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
    private fun scheduleBypassExpiryCheck(pkg: String, durationMs: Long, domain: String? = null) {
        // Chiave del runnable: per i siti e' pkg+dominio, cosi' bypass su due
        // domini diversi nello stesso browser hanno timer indipendenti.
        val mapKey = if (domain.isNullOrEmpty()) pkg else "$pkg|$domain"
        // Cancella eventuale runnable precedente per la stessa chiave
        // (es. utente ri-tocca "Open anyway" → nuova durata sostituisce la vecchia).
        pendingBypassExpiryChecks.remove(mapKey)?.let { mainHandler.removeCallbacks(it) }

        val r = object : Runnable {
            override fun run() {
                // Service hygiene: skip se il service e' stato distrutto.
                if (instance != this@KoruAccessibilityService) return
                pendingBypassExpiryChecks.remove(mapKey)
                // Double-check: il bypass potrebbe essere stato esteso nel frattempo.
                if (OverlayManager.isBypassed(pkg, domain)) {
                    Log.d(TAG, "Bypass re-check for $mapKey: still bypassed (renewed?), skipping")
                    return
                }
                // Se l'utente non è più nell'app bypassata, non serve far nulla:
                // al prossimo rientro scatterà normalmente checkAppBlocking.
                if (lastForegroundPackage != pkg) {
                    Log.d(TAG, "Bypass expired for $pkg but user not there (foreground=$lastForegroundPackage)")
                    return
                }
                Log.i(TAG, "Bypass TTL expired and user still in $pkg → showing extension prompt")
                showExtensionPrompt(pkg, domain)
            }
        }
        pendingBypassExpiryChecks[mapKey] = r
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
                // Skip solo se c'è un bypass NATO DAL limite (l'utente ha già
                // pagato la frizione del cap e ha tempo concesso). Un bypass di
                // profilo NON deve far saltare questo re-check, altrimenti il
                // cap non scatterebbe mai mentre il profilo è bypassato.
                if (OverlayManager.isLimitBypassActive(pkg)) {
                    Log.d(TAG, "Limit re-check for $pkg: limit bypass active, skipping")
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
    private fun showExtensionPrompt(pkg: String, domain: String? = null) {
        // Per i blocchi website il "label" e' il dominio, non l'app browser.
        val appLabel = domain ?: getAppLabel(pkg)
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
                blockedDomain = domain,
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
        // NB ordine dei guard (vedi anche [LockRunnable.checkAndBlock], che
        // DEVE restare allineato): ghost-guard → focus → daily limit →
        // bypass di profilo → profile loop. Il daily limit è valutato PRIMA
        // del bypass di profilo di proposito: il cap è un budget cumulativo e
        // un "Open anyway" su un blocco di profilo non deve ricaricarlo (era
        // il bug "+5 min all'infinito sul limite passando dal profilo").

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

        // Decisione DELEGATA a [BlockPolicyEvaluator]: focus → daily limit →
        // bypass di profilo → profile loop. L'ordine (e ogni guard) è
        // cross-checkato col vecchio inline; qui restano solo i side-effect.
        //
        // Letture d'ambiente identiche a prima:
        // - QuickBlock (focus): file store, cross-process (`:accessibility`).
        // - Limit (SEC-03 guarded): cap cumulativo anti clock-backward. Il
        //   flag `strict` è riletto live da AppUsageLimitsStore (cross-process)
        //   quindi una commutazione a strict mid-window è immediata.
        // - bypassReasonFor: chiude su OverlayManager.bypassReason col clock
        //   duale gestito nello store; per checkAppBlocking lo scope è sempre
        //   l'intero package (null), come il vecchio bypassReason(packageName).
        val qbSnapshot = QuickBlockStore.read(applicationContext)
        val focusShouldBlock = qbSnapshot.shouldBlock(packageName, System.currentTimeMillis())

        val limitEntry = AppUsageLimitsStore.entryFor(applicationContext, packageName)
        val limitMinutes = limitEntry?.minutes ?: 0
        // SEC-03: variante GUARDATA (monotonic anti clock-backward) per
        // l'enforcement del cap. Un cambio data all'indietro non azzera l'uso.
        val limitTodayMs = if (limitMinutes > 0) {
            UsageCounter.guardedTodayForegroundMs(applicationContext, packageName)
        } else 0L
        val limitMs = limitMinutes * 60_000L
        val isLimitStrict = limitEntry?.strict ?: true

        val decision = BlockPolicyEvaluator.evaluate(
            buildBlockQuery(
                packageName = packageName,
                snapshot = snapshot,
                limitMinutes = limitMinutes,
                isLimitStrict = isLimitStrict,
                limitTodayMs = limitTodayMs,
                focusShouldBlock = focusShouldBlock,
            ),
        )

        when (decision) {
            is BlockDecision.Block -> when (decision.reason) {
                BlockReason.FOCUS_MODE -> {
                    Log.w(TAG, ">>> BLOCKING APP (focus): $packageName")
                    currentlyBlockingPackage = packageName
                    val appLabel = getAppLabel(packageName)
                    mainHandler.post {
                        overlayManager?.show(
                            packageName = packageName,
                            appLabel = appLabel,
                            profileTitle = decision.profileTitle,
                            reason = BlockReason.FOCUS_MODE,
                            config = OverlayConfig.DEFAULT,
                            profileEmoji = decision.profileEmoji,
                        )
                    }
                    // FOCUS_MODE: forceHome=true. La user-intent del Pomodoro /
                    // focus session è uscire dall'app, non navigare lo stack
                    // interno. BACK su un'app con activity nested chiuderebbe
                    // solo l'inner activity e l'app resterebbe in foreground.
                    performGoHomeForBlock(forceHome = true, blockedPackage = packageName)
                    val now = System.currentTimeMillis()
                    try {
                        NativeDatabase.insertBlockSession(applicationContext, packageName, now)
                        NativeDatabase.insertRestrictedAccessEvent(
                            applicationContext,
                            packageName,
                            eventType = 0,
                            restrictionType = BlockingContract.RESTRICTION_TYPE_FOCUS_MODE,
                            timestamp = now,
                        )
                    } catch (_: Exception) {}
                    return true
                }

                BlockReason.USAGE_LIMIT -> {
                    Log.w(TAG, ">>> BLOCKING APP (daily limit, strict=${decision.isStrictLimit}): " +
                        "$packageName ${decision.todayMs / 60_000}min used, cap=${limitMinutes}min")
                    currentlyBlockingPackage = packageName
                    cancelLimitCheck(packageName)
                    val appLabel = getAppLabel(packageName)
                    // Config custom dall'eventuale relation per-app/profilo del
                    // pkg (branding del limite). Cercata su tutto lo snapshot
                    // perché il cap è globale, non profile-scoped.
                    val limitRelation = snapshot.profileApps.values.asSequence()
                        .flatten()
                        .firstOrNull { it.packageName == packageName }
                    val limitBaseConfig = OverlayConfig.fromJsonString(limitRelation?.overlayConfigJson)
                    val (overlayConfig, policy) = OverlayPolicies.buildUsageLimitOverlay(
                        applicationContext,
                        packageName,
                        baseConfig = limitBaseConfig,
                        isStrict = decision.isStrictLimit,
                    )
                    mainHandler.post {
                        overlayManager?.show(
                            packageName = packageName,
                            appLabel = appLabel,
                            profileTitle = decision.profileTitle,
                            reason = BlockReason.USAGE_LIMIT,
                            config = overlayConfig,
                            profileEmoji = decision.profileEmoji,
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
                            restrictionType = BlockingContract.RESTRICTION_TYPE_USAGE_LIMIT,
                            timestamp = now,
                        )
                    } catch (_: Exception) {}
                    return true
                }

                else -> { // APP_BLOCKED (gli altri reason non sono raggiungibili qui)
                    val profile = snapshot.profiles.firstOrNull { it.id == decision.profileId }
                    Log.w(TAG, ">>> BLOCKING APP: $packageName by '${decision.profileTitle}'")
                    currentlyBlockingPackage = packageName
                    val appLabel = getAppLabel(packageName)
                    val config = OverlayConfig.fromJsonString(decision.relation?.overlayConfigJson)
                    mainHandler.post {
                        overlayManager?.show(
                            packageName = packageName,
                            appLabel = appLabel,
                            profileTitle = decision.profileTitle,
                            reason = BlockReason.APP_BLOCKED,
                            config = config,
                            profileEmoji = decision.profileEmoji,
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
                            restrictionType = BlockingContract.RESTRICTION_TYPE_APP,
                            timestamp = now,
                        )
                    } catch (_: Exception) {}
                    if (profile != null) sendBlockingStateEvent(true, packageName, profile)
                    return true
                }
            }

            is BlockDecision.Allow -> {
                // L'evaluator collassa "bypass di profilo attivo" e "nessun
                // blocco" entrambi in Allow. Qui ri-discriminiamo (come prima)
                // leggendo lo stato di bypass per scegliere il bookkeeping:
                //  - bypass attivo ⇒ traccia il pkg per l'auto-revoke + (se cap
                //    non raggiunto) pianifica il re-check, MA non smontare
                //    l'overlay (l'app sta girando dentro il bypass);
                //  - nessun blocco ⇒ pianifica re-check del limite (se esiste)
                //    e smonta l'overlay residuo.
                if (OverlayManager.bypassReason(packageName) != null) {
                    Log.i(TAG, "BYPASS-ACTIVE: $packageName in foreground, tracking for auto-revoke")
                    lastBypassedActiveForeground = packageName
                    if (limitMinutes > 0 && limitTodayMs < limitMs) {
                        scheduleLimitCheck(packageName, limitMs - limitTodayMs)
                    }
                    return false
                }

                // Daily limit esiste ma cap non ancora raggiunto: re-check fra
                // (limitMs - limitTodayMs) ms così se l'utente resta dentro
                // l'app il blocco scatta quando il cap viene toccato, non solo
                // al prossimo window state change.
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
        }
    }

    /// Costruisce una [BlockQuery] per il path accessibility con l'ambiente
    /// risolto (clock/giorno/minuti/wifi) e `bypassReasonFor` che chiude su
    /// [OverlayManager.bypassReason]. I parametri opzionali coprono i 3 path:
    /// - app: domain/section null;
    /// - sezione: `sectionWireId` valorizzato (limit/focus = 0/false);
    /// - sito: `websiteScopeDomain` valorizzato + `profilesOverride` ristretto
    ///   al profilo che ha fatto match (limit/focus = 0/false).
    /// `bypassReasonFor(scope)`: scope==null ⇒ bypass per-app; per i siti il
    /// name regola; per le sezioni `section:<wireId>`.
    private fun buildBlockQuery(
        packageName: String,
        snapshot: ProfilesSnapshot,
        limitMinutes: Int = 0,
        isLimitStrict: Boolean = true,
        limitTodayMs: Long = 0L,
        focusShouldBlock: Boolean = false,
        websiteScopeDomain: String? = null,
        sectionWireId: String? = null,
        profilesOverride: List<NativeProfile>? = null,
    ): BlockQuery {
        val cal = Calendar.getInstance()
        return BlockQuery(
            packageName = packageName,
            profiles = profilesOverride ?: snapshot.profiles,
            profileApps = snapshot.profileApps,
            profileIntervals = snapshot.profileIntervals,
            profileWifis = snapshot.profileWifis,
            limitMinutes = limitMinutes,
            isLimitStrict = isLimitStrict,
            limitTodayMs = limitTodayMs,
            focusShouldBlock = focusShouldBlock,
            bypassReasonFor = { scope -> OverlayManager.bypassReason(packageName, scope) },
            nowWallMs = System.currentTimeMillis(),
            nowMinutesOfDay = currentMinutesOfDay(cal),
            todayDayFlag = currentDayFlag(cal),
            currentWifiSsid = getCurrentWifiSsid(),
            websiteScopeDomain = websiteScopeDomain,
            sectionWireId = sectionWireId,
        )
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

        // Decisione DELEGATA: l'evaluator scorre i profili attivi ORA, controlla
        // relation esiste + app NON bloccata interamente (!isEnabled) +
        // blockedSectionsJson contiene il wireId, e applica il CR-07 bypass
        // guard scoped `section:<wireId>`. Qui restano solo overlay/HOME/log.
        val decision = BlockPolicyEvaluator.evaluate(
            buildBlockQuery(
                packageName = packageName,
                snapshot = snapshot,
                sectionWireId = detected.wireId,
            ),
        )
        val block = decision as? BlockDecision.Block ?: return false
        if (block.reason != BlockReason.SECTION_BLOCKED) return false

        val profile = snapshot.profiles.firstOrNull { it.id == block.profileId }
        Log.w(TAG, ">>> BLOCKING SECTION ${detected.wireId} in $packageName by '${block.profileTitle}'")
        val appLabel = getAppLabel(packageName)
        val config = OverlayConfig.fromJsonString(block.relation?.overlayConfigJson)
        mainHandler.post {
            overlayManager?.show(
                packageName = packageName,
                appLabel = appLabel,
                profileTitle = block.profileTitle,
                reason = BlockReason.SECTION_BLOCKED,
                config = config,
                profileEmoji = block.profileEmoji,
                // CR-07: scope del bypass = `section:<wireId>` (era null). Senza
                // questo, "Open anyway" su una sezione marcava il bypass keyed
                // all'INTERO package, ma il guard dell'evaluator legge la chiave
                // `section:<wireId>` → il bypass non aveva alcun effetto e
                // l'overlay si ripresentava subito. Ora la chiave del mark
                // (OverlayManager.show → markBypassed con _blockedDomain) e il
                // guard (BlockPolicyEvaluator: bypassReasonFor("section:<id>"))
                // combaciano.
                blockedDomain = block.bypassScopeDomain,
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
                restrictionType = BlockingContract.RESTRICTION_TYPE_SECTION,
                timestamp = now,
            )
        } catch (_: Exception) {}
        if (profile != null) sendSectionEvent(packageName, detected.wireId, profile)
        return true
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
            if (BuildConfig.DEBUG) Log.d(TAG, "  → URL bar not detected (configs=${configs.size})")
            return
        }
        // SEC-07: la URL completa (path + query) è cronologia di navigazione =
        // PII per una app di benessere digitale. NON loggarla mai in release;
        // anche in debug logghiamo solo il dominio matchato, mai full URL/query.
        if (BuildConfig.DEBUG) Log.d(TAG, "  URL detected: domain=${detected.domain}")

        if (snapshot.websiteRulesCache.isEmpty()) {
            Log.w(TAG, "  → websiteRulesCache is EMPTY")
            return
        }

        for ((profileId, rules) in snapshot.websiteRulesCache) {
            // Gating temporale: blocca i domini solo se il profilo è attivo
            // ORA (time interval, dayFlags, pausa, onUntil, wifi). Questo
            // `continue` esplicito preserva la semantica di loop (profilo
            // inattivo → passa al prossimo) — l'evaluator ricontrolla l'active
            // now sul query single-profilo, ma il check qui distingue
            // "inattivo" (skip) da "bypassato" (stop) sul ramo Allow sotto.
            val matchedProfile = snapshot.profiles.firstOrNull { it.id == profileId }
            if (matchedProfile == null || !isProfileActiveNow(matchedProfile, snapshot)) continue
            // SEC-07: i nomi delle regole sono pattern di blocco scelti dall'utente
            // (config sensibile) → solo in debug.
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "  profile $profileId has ${rules.size} rules: ${rules.map { "${it.name}(type=${it.blockingType},any=${it.isAnywhereInUrl})" }}")
            }
            val matchedRule = WebsiteMatcher.firstMatch(rules, detected.fullUrl, detected.domain) ?: continue

            // Bypass PER-DOMINIO: l'utente ha scelto "Open anyway" + durata su
            // QUESTO dominio. La chiave è il name della regola che ha fatto
            // match (stabile su www/sottodomini). Il guard è DELEGATO
            // all'evaluator (query single-profilo, websiteScopeDomain =
            // bypassDomain) — reason-agnostic come prima (un dominio non ha un
            // cap cumulativo). Se un giorno si introduce un limite di tempo
            // PER-DOMINIO, andrà modellato nell'evaluator come per il cap app.
            val bypassDomain = matchedRule.name.lowercase().trim()
            val decision = BlockPolicyEvaluator.evaluate(
                buildBlockQuery(
                    packageName = packageName,
                    snapshot = snapshot,
                    websiteScopeDomain = bypassDomain,
                    profilesOverride = listOf(matchedProfile),
                ),
            )
            if (decision is BlockDecision.Allow) {
                // Profilo attivo (già verificato sopra) ⇒ l'Allow qui è per il
                // bypass per-dominio: traccia il browser per l'auto-revoke
                // all'uscita (clearBypass azzera tutti i domini del package) e
                // ferma la scansione (stesso behavior del vecchio `return`).
                lastBypassedActiveForeground = packageName
                return
            }
            val block = decision as BlockDecision.Block // WEBSITE_BLOCKED

            Log.w(TAG, ">>> BLOCKING SITE: ${detected.domain} by profile $profileId (rule=$bypassDomain)")
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
                    profileTitle = block.profileTitle,
                    reason = BlockReason.WEBSITE_BLOCKED,
                    profileEmoji = block.profileEmoji,
                    blockedDomain = block.bypassScopeDomain,
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
                    restrictionType = BlockingContract.RESTRICTION_TYPE_WEBSITE,
                    timestamp = now,
                )
            } catch (_: Exception) {}
            return
        }
    }

    /// Thin wrapper Android attorno a [BlockPolicyEvaluator.isProfileActiveNow]:
    /// risolve l'ambiente (clock, giorno, minuti, wifi) e delega la logica
    /// pura. La decisione è la stessa usata da [checkAppBlocking] e dagli altri
    /// path via [evaluateBlock] — questo metodo resta per i call site che
    /// vogliono solo il booleano "attivo ora" di un singolo profilo.
    private fun isProfileActiveNow(
        profile: NativeProfile,
        snapshot: ProfilesSnapshot = profilesSnapshot.get(),
    ): Boolean = BlockPolicyEvaluator.isProfileActiveNow(
        profile = profile,
        intervals = snapshot.profileIntervals[profile.id] ?: emptyList(),
        wifiSet = snapshot.profileWifis[profile.id],
        nowWallMs = System.currentTimeMillis(),
        nowMinutesOfDay = currentMinutesOfDay(),
        todayDayFlag = currentDayFlag(),
        currentWifiSsid = getCurrentWifiSsid(),
    )

    /// Bit del giorno corrente (allineato a [BlockPolicyEvaluator] e a DayFlags
    /// lato Dart). Lun=1, Mar=2, Mer=4, Gio=8, Ven=16, Sab=32, Dom=64.
    private fun currentDayFlag(cal: Calendar = Calendar.getInstance()): Int =
        when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 4
            Calendar.THURSDAY -> 8
            Calendar.FRIDAY -> 16
            Calendar.SATURDAY -> 32
            Calendar.SUNDAY -> 64
            else -> 0
        }

    /// Minuto-del-giorno corrente (0..1439), ora locale.
    private fun currentMinutesOfDay(cal: Calendar = Calendar.getInstance()): Int =
        cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

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

    /// Legge il SSID corrente. Delega all'helper condiviso [currentWifiSsid]
    /// (vedi WifiSsidProvider.kt) usato anche dal backup [LockRunnable] — una
    /// sola implementazione, nessuna parità-per-copia (CR-03).
    private fun getCurrentWifiSsid(): String? = currentWifiSsid(applicationContext)

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
