package com.dev.koru.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.dev.koru.BuildConfig
import com.dev.koru.browser.BrowserConfigLoader
import com.dev.koru.browser.BrowserUrlDetector
import com.dev.koru.browser.WebsiteMatcher
import com.dev.koru.contract.BlockingContract
import com.dev.koru.content.InAppContentDetector
import com.dev.koru.diagnostics.BlackBox
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.db.NativeWebsiteRule
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig
import com.dev.koru.strictmode.StrictModeEnforcer
import com.dev.koru.strictmode.StrictModeFailSafe
import java.util.Calendar
import java.util.concurrent.atomic.AtomicReference

/**
 * Koru blocking engine running inside an AccessibilityService.
 *
 * Event-driven su TYPE_WINDOW_STATE_CHANGED — quando rileva un'app bloccata
 * da un profilo attivo:
 *   1. Mostra l'overlay Koru via [OverlayManager] (ComposeView sopra tutto).
 *   2. Performa GLOBAL_ACTION_HOME per riportare l'utente alla home.
 *
 * INVARIANTE LOAD-BEARING: il service gira nel processo MAIN (il manifest NON
 * dichiara `android:process` — vedi il commento lì). I singleton in-memory
 * condivisi con engine Flutter e channel handler ([LauncherRecentsGate],
 * [OpenAppsTracker], la cache di StrictModeEnforcer) funzionano SOLO perché
 * tutto vive in un processo: spostare il service in un `:accessibility`
 * separato li romperebbe in silenzio (flag mai visibili cross-process,
 * mask sempre fail-secure). L'OverlayManager qui è distinto da quello di
 * LockForegroundService per ownership del lifecycle, non per processo.
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

        /// Delay del re-check post ghost-skip (vedi [scheduleGhostRecheck]):
        /// primo tentativo a 800ms (il lag di flush UsageStats osservato
        /// on-device era ~0.6-1.1s sotto carico unlock/animazione), retry
        /// singolo a +1.5s — copertura totale ~2.3s.
        private const val GHOST_RECHECK_DELAY_MS = 800L
        private const val GHOST_RECHECK_RETRY_DELAY_MS = 1_500L

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

        /// Package da NON trattare mai come "app in foreground da valutare":
        /// framework, systemui e launcher di sistema. Promosso a companion
        /// (era property d'istanza) per il riuso da [LauncherRecentsGate],
        /// [OpenAppsTracker] e [RecentsDetector.isRecentsHostWindow].
        internal val SKIP_PACKAGES: Set<String> = setOf(
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
            // OnePlus OxygenOS ≤11 usa net.oneplus.launcher (l'entry sopra
            // non esiste su device reali ma resta per sicurezza). Questo set
            // è anche il canale di CONSEGNA degli eventi recents: un host
            // fuori da qui non entra nel watched-set dinamico e il blocco
            // gesture/clear-all muore in silenzio su quegli OEM.
            "net.oneplus.launcher",
            "com.bbk.launcher2", // Vivo
            "com.hihonor.android.launcher", // Honor
            "com.mi.android.globallauncher", // Xiaomi POCO/global
            "com.sonymobile.home", // Sony
            "com.asus.launcher", // Asus
            "com.nothing.launcher", // Nothing
            "com.coloros.safecenter",
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

    /// Anti-loop guard: timestamp dell'ultimo HOME intent rilanciato. Con
    /// l'app bloccata che si ripiglia il foreground a raffica (mini-player YT /
    /// inner stack IG, vedi nota in [scheduleBackFallbackHome]) il relaunch HOME
    /// veniva sparato in loop, e ogni giro (con engine NON cached) ricreava
    /// l'Activity + un `main()` da zero (osservato nei black-box: onCreate→
    /// onStop→onDestroy ×3 in 6s). Coalesciamo gli echi ravvicinati.
    @Volatile private var lastHomeIntentMs = 0L
    private val homeRelaunchMinIntervalMs = 800L

    private fun goToHomeViaIntent() {
        val now = System.currentTimeMillis()
        if (now - lastHomeIntentMs < homeRelaunchMinIntervalMs) {
            // Echo ravvicinato. Se il foreground reale è GIÀ Koru, il HOME
            // precedente è atterrato e questo è ridondante → skip (rompe il
            // loop di ricreazione). Se invece il target è ANCORA in foreground
            // (si è ri-asserito), NON skippiamo: l'enforcement deve procedere.
            val fg = ForegroundDetector.detect(applicationContext)?.primaryPackage
            if (fg == packageName) {
                BlackBox.log(
                    "HOME",
                    "relaunch SKIP ridondante (Δ=${now - lastHomeIntentMs}ms, fg=$fg già home)",
                )
                return
            }
            BlackBox.log(
                "HOME",
                "relaunch (Δ=${now - lastHomeIntentMs}ms, fg=$fg ancora foreground → procedo)",
            )
        } else {
            BlackBox.log("HOME", "relaunch (Δ=${now - lastHomeIntentMs}ms)")
        }
        lastHomeIntentMs = now
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

    /// Chiede il focus audio TRANSIENT per mettere in pausa il media dell'app
    /// sotto un overlay-over-app. Idempotente: se già detenuto, no-op.
    private fun requestMediaPause() {
        if (mediaPauseFocusRequest != null) return
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                            .build(),
                    )
                    .setOnAudioFocusChangeListener(mediaPauseFocusListener)
                    .build()
                am.requestAudioFocus(req)
                mediaPauseFocusRequest = req
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    mediaPauseFocusListener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
                )
                mediaPauseFocusRequest = mediaPauseFocusListener
            }
            Log.d(TAG, "Media pause: audio focus acquired")
        } catch (e: Exception) {
            Log.w(TAG, "requestMediaPause failed: ${e.message}")
        }
    }

    /// Rilascia il focus audio chiesto da [requestMediaPause] → l'app
    /// sottostante può riprendere la riproduzione. Idempotente.
    private fun releaseMediaPause() {
        val held = mediaPauseFocusRequest ?: return
        mediaPauseFocusRequest = null
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && held is AudioFocusRequest) {
                am.abandonAudioFocusRequest(held)
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(mediaPauseFocusListener)
            }
            Log.d(TAG, "Media pause: audio focus released")
        } catch (e: Exception) {
            Log.w(TAG, "releaseMediaPause failed: ${e.message}")
        }
    }

    /// Termina la sessione "overlay-over-app" corrente (se presente): azzera il
    /// tracking e rilascia il focus audio. Chiamato quando il blocco over-app
    /// finisce in QUALSIASI modo — bypass concesso, "Don't open", passaggio a
    /// un'altra app, blocco "duro" sopravvenuto (focus/limite/sezione),
    /// profilo non più attivo, screen-off, destroy. Idempotente.
    private fun endOverlayOverApp() {
        if (overlayOverAppPackage != null) {
            overlayOverAppPackage = null
        }
        releaseMediaPause()
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

    /// Chiamato su Intent.ACTION_SCREEN_OFF (display off / lock).
    /// L'overlay non e' utile a schermo spento e, peggio, se resta attaccato
    /// crea il bug: al re-sblocco su un'app diversa (es. WhatsApp da notifica)
    /// l'overlay stale sopra l'app innocente intercetterebbe il tap del
    /// bottone "Don't open" e GLOBAL_ACTION_BACK colpirebbe WhatsApp invece
    /// del target originale. Dismiss + reset del tracking + cancellazione
    /// di tutti i runnable schedulati (timer di limit, expiry bypass,
    /// fallback BACK→HOME): scattare a schermo off e' no-op nel migliore
    /// dei casi e disturbo nel peggiore. checkAppBlocking li rischedula
    /// al prossimo window-state-change utile.
    ///
    /// Il lock chiude anche la SESSIONE di bypass: stessa semantica
    /// dell'uscita dall'app ("una sessione = una scelta"). Revoca ALL invece
    /// di clearBypass(lastBypassedActiveForeground) perche' il tracker puo'
    /// essere andato perso (service restart a meta' sessione: onDestroy lo
    /// nulla e viene ri-popolato solo al prossimo window event) — e per
    /// l'invariante dell'exit-revoke al massimo un package ha bypass attivi,
    /// quindi "all" e il pkg tracciato coincidono quando il tracking c'e'.
    /// Al re-sblocco handleUserPresent ri-esegue checkAppBlocking sul
    /// foreground reale → l'overlay ricompare senza altro codice.
    private fun handleScreenOff() {
        Log.d(TAG, "SCREEN_OFF: dismiss overlay + cancel pending runnables")
        mainHandler.post {
            overlayManager?.dismiss()
            currentlyBlockingPackage = null
            preLaunchOverlayPackage = null
            // Schermo spento durante un overlay-over-app: chiudi la sessione e
            // rilascia il focus audio (niente media da mettere in pausa a display off).
            endOverlayOverApp()
            pendingBackFallbacks.values.forEach { mainHandler.removeCallbacks(it) }
            pendingBackFallbacks.clear()
            pendingBypassExpiryChecks.values.forEach { mainHandler.removeCallbacks(it) }
            pendingBypassExpiryChecks.clear()
            pendingLimitChecks.values.forEach { mainHandler.removeCallbacks(it) }
            pendingLimitChecks.clear()
            pendingWindowBoundaryChecks.values.forEach { mainHandler.removeCallbacks(it) }
            pendingWindowBoundaryChecks.clear()
            // Re-check ghost a schermo spento e' inutile (UsageStats vedrebbe
            // comunque l'app sotto il keyguard): all'unlock e' handleUserPresent
            // a rifare il check sul foreground reale.
            pendingGhostRechecks.values.forEach { mainHandler.removeCallbacks(it) }
            pendingGhostRechecks.clear()
            Log.i(TAG, "BYPASS-REVOKE-DO: screen off → revoke session bypasses (was tracking $lastBypassedActiveForeground)")
            OverlayManager.revokeAllBypasses()
            lastBypassedActiveForeground = null
            // Niente recents visibili a schermo spento: chiudi sessione/token
            // del gate e l'eventuale kick pending.
            LauncherRecentsGate.onScreenOff(this)
        }
    }

    /// Chiamato su Intent.ACTION_USER_PRESENT (unlock attivo dell'utente).
    /// Se l'utente sblocca direttamente su un'app limitata (es. resume di
    /// Instagram che era in foreground al lock), Android puo' non emettere
    /// un nuovo TYPE_WINDOW_STATE_CHANGED — l'app non e' "riaperta", e' gia'
    /// resumed. Senza questo re-check l'overlay non comparirebbe finche'
    /// l'utente non navigasse altrove e tornasse. Interroghiamo UsageStats
    /// per il foreground reale e rilanciamo checkAppBlocking.
    ///
    /// overAppIfBlocked=true: l'app era gia' aperta al lock, quindi un
    /// eventuale blocco di profilo (es. bypass revocato dallo screen-off)
    /// mostra l'overlay SOPRA l'app senza espellerla — chiusa solo se
    /// l'utente sceglie "Don't open", come per pre-lancio e deep-link.
    private fun handleUserPresent() {
        val fg = ForegroundDetector.detect(applicationContext)?.primaryPackage
        Log.d(TAG, "USER_PRESENT: foreground=$fg → re-check if blocked")
        if (fg == null || SKIP_PACKAGES.contains(fg) || fg == packageName) return
        mainHandler.post {
            checkAppBlocking(fg, profilesSnapshot.get(), overAppIfBlocked = true)
        }
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

    @Volatile
    private var actionReceiver: BroadcastReceiver? = null
    @Volatile
    private var screenStateReceiver: BroadcastReceiver? = null
    @Volatile
    private var inAppDetector: InAppContentDetector? = null
    @Volatile
    private var lastSectionEventTime = 0L
    @Volatile
    private var lastDetectedSectionWireId: String? = null

    @Volatile
    private var overlayManager: OverlayManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /// Package attualmente bloccato in modalità "overlay SOPRA l'app". Quando
    /// un'app bloccata viene aperta da un LINK / da un'altra app (non
    /// dall'icona del launcher), mostriamo l'overlay sopra di essa SENZA
    /// espellerla (niente BACK/HOME): così "Apri comunque" si limita a
    /// dismissare l'overlay e rivela esattamente il contenuto del deep link
    /// (es. il video YouTube mandato da un amico), invece di rilanciare l'app
    /// con `getLaunchIntentForPackage` che la porterebbe alla home perdendo il
    /// deep link. `null` = blocco "duro" classico (kick-out alla home).
    /// La sessione over-app termina in [endOverlayOverApp] (bypass, "Don't
    /// open", uscita verso un'altra app, screen-off, profilo non più attivo).
    @Volatile
    private var overlayOverAppPackage: String? = null

    /// Package per cui è mostrato un overlay di blocco PRE-LANCIO: l'utente ha
    /// toccato l'icona dall'UI di Koru (launcher/drawer/favoriti) e
    /// [showPreLaunchBlockIfNeeded] ha mostrato l'overlay PRIMA di aprire l'app
    /// (niente apri→espelli→riapri). Differenza chiave rispetto al blocco
    /// classico: l'app NON è mai stata aperta, quindi "Don't open" deve solo
    /// dismissare l'overlay (siamo già sul launcher) — non BACK/HOME, che
    /// navigherebbe/resetterebbe il launcher. "Open anyway" invece passa per il
    /// ramo standard `!appStillForeground` di [onBypassOpen] →
    /// startActivity(getLaunchIntentForPackage) = apre l'app per la prima volta.
    /// Azzerato appena un evento app REALE supera lo stato pre-lancio
    /// (checkAppBlocking), su "Open anyway"/"Don't open", screen-off e destroy.
    /// `null` = nessun overlay pre-lancio in corso.
    @Volatile
    private var preLaunchOverlayPackage: String? = null

    /// AudioFocusRequest attivo finché un overlay-over-app è visibile. Mentre
    /// l'overlay copre il video l'app sotto continua a girare, quindi chiediamo
    /// il focus audio TRANSIENT per metterne in PAUSA il media durante il
    /// countdown (l'audio bleed-through sarebbe fastidioso). Rilasciato in
    /// [endOverlayOverApp] → l'app può riprendere la riproduzione. Tipo `Any?`
    /// per non legare il field all'API 26+ ([AudioFocusRequest] esiste da O).
    @Volatile
    private var mediaPauseFocusRequest: Any? = null

    /// Listener no-op richiesto da [AudioFocusRequest]/requestAudioFocus: non
    /// reagiamo ai cambi di focus (non stiamo riproducendo nulla noi), ci serve
    /// solo "rubare" il focus per mettere in pausa l'app sottostante.
    private val mediaPauseFocusListener =
        AudioManager.OnAudioFocusChangeListener { /* no-op: non riproduciamo audio */ }

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

    /// Runnable schedulati al PROSSIMO confine di finestra oraria, uno per
    /// package in foreground. Coprono il caso "confine attraversato mentre
    /// l'utente è già dentro l'app": a quel confine non arriva alcun
    /// TYPE_WINDOW_STATE_CHANGED, quindi senza questo timer una finestra che
    /// INIZIA (es. 14:00) mentre l'app è aperta non bloccherebbe mai finché
    /// l'utente non genera un nuovo evento (bug osservato con profilo
    /// 9-13/14-18). Stesso pattern di [pendingLimitChecks].
    private val pendingWindowBoundaryChecks = mutableMapOf<String, Runnable>()

    /// Runnable di RE-CHECK schedulati quando il ghost-guard scarta un evento,
    /// uno per package scartato. Coprono la race "quick-switch committato ma
    /// UsageStats non ha ancora flushato il RESUMED": l'evento finestra
    /// dell'app target arriva PRIMA che ForegroundDetector la veda come
    /// foreground reale → il guard la classifica ghost e dentro l'app non
    /// arrivano altri window event → l'intera sessione resterebbe sbloccata
    /// (bug osservato: WhatsApp→Instagram 6s dopo l'unlock, 30s senza blocco).
    /// Il re-check ri-legge UsageStats a flush avvenuto: se l'app È il
    /// foreground reale l'evento era genuino → checkAppBlocking vero; se non
    /// lo è, era davvero un ghost → no-op. Stesso pattern di
    /// [pendingLimitChecks]/[scheduleBackFallbackHome].
    private val pendingGhostRechecks = mutableMapOf<String, Runnable>()

    /// STRUMENTAZIONE FLASH (tag A11Y-FLASH): uptime dell'evento window-change
    /// che ha innescato la valutazione di un pkg, per misurare il ritardo
    /// evento→decisione di blocco. Un dt ~800ms rivela che la decisione è
    /// arrivata dal ghost-recheck differito (falso ghost su lancio esterno);
    /// un dt di pochi ms = blocco sincrono. Solo-main-thread come
    /// [pendingGhostRechecks]; rimosso alla decisione (block/allow) e al
    /// verdetto "ghost reale" del re-check. Serve a quantificare il contributo
    /// del rinvio ghost vs l'inflazione dell'overlay PRIMA di intervenire.
    private val blockTriggerUptimeMs = mutableMapOf<String, Long>()

    /// STRUMENTAZIONE FLASH: ritardo di CONSEGNA dell'evento window-change =
    /// (uptime all'ingresso di onAccessibilityEvent) - (event.eventTime, istante
    /// in cui l'evento è stato generato dal sistema). Cattura il contributo di
    /// notificationTimeout + coda di dispatch, cioè la latenza PRE-codice che
    /// il timer evento→decisione non vede. Solo-main-thread; stesso ciclo di
    /// vita di [blockTriggerUptimeMs].
    private val blockTriggerDeliveryMs = mutableMapOf<String, Long>()

    /// Throttle per TYPE_WINDOW_CONTENT_CHANGED nei browser: limita la lettura
    /// della URL bar (operazione relativamente costosa) a max 2/s.
    @Volatile
    private var lastBrowserContentCheckMs = 0L
    @Volatile
    private var lastBrowserContentPkg: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        BlackBox.log("A11Y", "onServiceConnected — accessibility service attivo")
        // Prime async della strict-mask: la prima readMask (round-trip Keystore)
        // avviene off-main ORA, al connect, così `getMask` durante i successivi
        // window-event trova sempre la cache popolata e non blocca mai il main.
        StrictModeEnforcer.prime(applicationContext)
        inAppDetector = InAppContentDetector(applicationContext)
        overlayManager = OverlayManager(applicationContext).apply {
            onReturnHome = onReturnHome@{ forceHome ->
                // Tap esplicito dall'overlay: il flag `forceHome` decide
                // se forzare HOME (Intent) o tentare BACK prima con
                // fallback HOME. La policy è scelta in OverlayManager
                // in base alla BlockReason: APP_BLOCKED → BACK (preserva
                // sub-pagina launcher), BYPASS_EXPIRED/USAGE_LIMIT/SECTION
                // → HOME forzato (l'utente vuole uscire univocamente
                // dall'app con stack interno tipo Instagram-storia).
                //
                // Stale-guard: se il foreground reale non coincide col
                // target dell'overlay (es. utente ha bloccato schermo +
                // aperto WhatsApp da notification trampoline e l'overlay
                // di Instagram e' rimasto stale sopra), BACK/HOME
                // colpirebbe WhatsApp (innocente). Verifichiamo via
                // ForegroundDetector (UsageStats authoritative) con
                // fallback su lastForegroundPackage (Accessibility recente).
                // Se entrambi unavailable: trust-the-system, procediamo.
                val targetPkg = overlayManager?.currentPackageName ?: ""
                // PRE-LANCIO: overlay mostrato PRIMA di aprire l'app (tap
                // sull'icona dall'UI di Koru — vedi [showPreLaunchBlockIfNeeded]).
                // L'app non è mai stata aperta: "Don't open" = solo dismiss,
                // niente BACK/HOME (siamo sul launcher; un BACK lo navigherebbe,
                // un HOME ne resetterebbe la pagina). L'app resta non aperta.
                if (preLaunchOverlayPackage != null && preLaunchOverlayPackage == targetPkg) {
                    Log.i(TAG, "PRE-LAUNCH 'Don't open' for $targetPkg — dismiss only (app mai aperta)")
                    preLaunchOverlayPackage = null
                    currentlyBlockingPackage = null
                    dismiss()
                    return@onReturnHome
                }
                // Overlay-over-app: l'app bloccata è ANCORA in foreground sotto
                // l'overlay (non l'abbiamo mai espulsa). Un BACK (forceHome=false,
                // il default per APP_BLOCKED) la navigherebbe solo internamente
                // lasciandola aperta → serve HOME "duro" per chiuderla davvero.
                val effectiveForceHome = forceHome || (overlayOverAppPackage == targetPkg)
                val realFg = ForegroundDetector.detect(applicationContext)?.primaryPackage
                val accFg = lastForegroundPackage
                val stale = isStaleOverlayClick(targetPkg, realFg, accFg)
                if (stale) {
                    Log.w(TAG, "STALE overlay click: target=$targetPkg realFg=$realFg accFg=$accFg" +
                        " — dismiss only, no BACK/HOME (foreground app is not the block target)")
                    dismiss()
                    currentlyBlockingPackage = null
                    pendingBackFallbacks.remove(targetPkg)?.let { mainHandler.removeCallbacks(it) }
                    pendingLimitChecks.remove(targetPkg)?.let { mainHandler.removeCallbacks(it) }
                } else {
                    performGoHomeForBlock(
                        forceHome = effectiveForceHome,
                        blockedPackage = targetPkg.ifEmpty { null },
                    )
                    dismiss()
                }
                // L'utente ha scelto "Don't open": la sessione over-app è finita
                // (rilascia il focus audio, l'app verrà comunque chiusa da HOME).
                endOverlayOverApp()
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
                // "Open anyway": se l'overlay era PRE-LANCIO, l'app sta per
                // essere aperta dal ramo !appStillForeground qui sotto
                // (getLaunchIntentForPackage) → non è più uno stato pre-lancio.
                preLaunchOverlayPackage = null
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
                BlockEventLogger.logRestrictedAccess(
                    applicationContext,
                    pkg,
                    eventType = 1, // SKIPPED
                    restrictionType = BlockingContract.RESTRICTION_TYPE_APP,
                    timestamp = System.currentTimeMillis(),
                )
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
                // Discriminator: il rilancio via startActivity serve SOLO quando
                // abbiamo espulso l'app (HOME) e dunque non è più in foreground —
                // i blocchi "duri" APP_BLOCKED/USAGE_LIMIT/FOCUS_MODE da icona.
                // In DUE casi l'app è invece ANCORA in foreground sotto l'overlay
                // e basta dismissare:
                //  - BYPASS_EXPIRED (showExtensionPrompt non fa HOME);
                //  - OVERLAY-OVER-APP (apertura da link: non abbiamo MAI espulso).
                // In overlay-over-app il rilancio sarebbe anzi il BUG da evitare:
                // getLaunchIntentForPackage manda l'app alla home (ACTION_MAIN)
                // perdendo il deep link — es. lo Short YouTube mandato da un amico.
                // Dismissando e basta, il video sotto l'overlay resta esattamente
                // dov'era.
                //
                // NB: NON usiamo `lastForegroundPackage == pkg` come signal — il
                // launcher è in skipPackages, quindi dopo HOME `lastForegroundPackage`
                // resta sull'app bloccata e il check sarebbe sempre true (era il
                // bug "Open anyway non rilancia mai l'app").
                val appStillForeground =
                    overlayManager?.currentReason() == BlockReason.BYPASS_EXPIRED ||
                        overlayOverAppPackage == pkg
                if (!appStillForeground) {
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
                // Bypass concesso: la sessione over-app (se attiva) è finita —
                // rilascia il focus audio così l'app sotto può riprendere la
                // riproduzione e azzera il tracking. Idempotente altrimenti.
                endOverlayOverApp()
            }
        }
        // Scalda il runtime Compose dell'overlay ORA (fuori dal path di blocco):
        // il primo blocco reale dopo questo cold-start eviterà i ~70ms di
        // class-loading Compose misurati al primo addView (tag A11Y-FLASH).
        overlayManager?.prewarm()

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

        // Screen state observer: SCREEN_OFF → dismiss l'overlay (l'utente
        // non lo sta vedendo comunque) + cancella runnable schedulati che
        // scatterebbero sopra il keyguard senza senso. USER_PRESENT (unlock
        // attivo) → re-check del foreground: se l'utente sblocca direttamente
        // su un'app limitata, il resume potrebbe non emettere un nuovo
        // TYPE_WINDOW_STATE_CHANGED e l'overlay non comparirebbe.
        screenStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> handleScreenOff()
                    Intent.ACTION_USER_PRESENT -> handleUserPresent()
                }
            }
        }
        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        // SCREEN_OFF/USER_PRESENT sono broadcast di sistema: il flag
        // RECEIVER_NOT_EXPORTED e' inoffensivo (il sistema le invia comunque)
        // ma mantenerlo per parita' stilistica col blocco sopra.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenStateReceiver, screenFilter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenStateReceiver, screenFilter)
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

        // Click events: consegnati SOLO mentre una sessione recents è attiva
        // (LauncherRecentsGate abilita typeViewClicked dinamicamente via
        // serviceInfo, come applyDynamicPackageFilter fa con packageNames).
        // Rileva "Cancella tutto" → reset del contatore schede. Early-return:
        // mai sul path di blocking.
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            LauncherRecentsGate.onViewClicked(this, event)
            return
        }

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
            // Sync del contatore schede con le card REALI mentre le recents
            // sono aperte (sessione legittima): lo swipe-dismiss di una
            // singola scheda non genera altri eventi osservabili — questa è
            // l'unica finestra in cui esiste una ground-truth.
            if (LauncherRecentsGate.maybeSyncOpenApps(this, pkg)) return
            if (!BrowserConfigLoader.isBrowser(applicationContext, pkg)) return
            val now = System.currentTimeMillis()
            val samePkg = pkg == lastBrowserContentPkg
            if (samePkg && now - lastBrowserContentCheckMs < 500) return
            lastBrowserContentCheckMs = now
            lastBrowserContentPkg = pkg
            if (now - lastProfileLoadTime > 10_000) loadProfiles()
            // Recupera snapshot aggiornato dopo eventuale reload.
            val freshSnapshot = profilesSnapshot.get()
            // CR-08: ricontrolla PRIMA app/limit/focus, poi (se non bloccato)
            // il sito — stesso ordine del ramo TYPE_WINDOW_STATE_CHANGED. Un
            // browser può finire sotto un daily-limit o un focus/quick-block che
            // PARTE mentre l'utente è già dentro (genera content-change ma non
            // window-state-change): senza questo, su quegli eventi il cap / la
            // transizione di focus non venivano rivalutati. scheduleLimitCheck
            // mitiga parzialmente il solo caso daily-limit; questo copre anche il
            // focus-iniziato-mentre-dentro (belt-and-suspenders, fail-secure:
            // può solo bloccare di più, mai di meno).
            if (checkAppBlocking(pkg, freshSnapshot)) return
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

        // Gate launcher-scoped sulle recents (gesture swipe-up-hold bloccata
        // mentre il launcher Koru è in cima; allow-token per l'apertura via
        // icona). DEVE stare DOPO lo strict check (strict vince: il token non
        // può fare da bypass di BLOCK_RECENT_APPS) e PRIMA del return
        // SKIP_PACKAGES (l'host delle recents È nello skip-set).
        if (LauncherRecentsGate.handleEvent(this, event)) return

        if (SKIP_PACKAGES.contains(pkg) || pkg == packageName) {
            // Launcher o Koru stesso in foreground — NON dismiss overlay:
            // siamo probabilmente qui proprio perché abbiamo fatto HOME dopo
            // aver bloccato un'app. L'overlay deve restare visibile sopra il
            // launcher finché l'utente non apre un'app diversa (gestito sotto
            // in checkAppBlocking) o tocca "Go back" sull'overlay.
            return
        }

        lastForegroundPackage = pkg
        // Add opportunistico al contatore "schede aperte" (la fonte di verità
        // resta la sweep UsageStats in OpenAppsTracker.refresh — il watched-set
        // dinamico filtra questi eventi alle sole app con profilo/limite).
        OpenAppsTracker.noteForeground(applicationContext, pkg)

        val now = System.currentTimeMillis()
        if (now - lastProfileLoadTime > 10_000) loadProfiles()
        val freshSnapshot = profilesSnapshot.get()

        // STRUMENTAZIONE FLASH: marca l'istante dell'evento window-change PRIMA
        // di checkAppBlocking. Se l'app viene ghost-scartata, il valore resta
        // nel map e verrà consumato dalla decisione del re-check differito,
        // rendendo visibile su BlackBox (tag A11Y-FLASH) il ritardo di ~800ms.
        // Cattura anche il ritardo di CONSEGNA (entry - event.eventTime), cioè
        // la latenza pre-codice (notificationTimeout + coda dispatch).
        val flashEntryUptime = SystemClock.uptimeMillis()
        blockTriggerUptimeMs[pkg] = flashEntryUptime
        blockTriggerDeliveryMs[pkg] = flashEntryUptime - event.eventTime
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
    internal inline fun withRootInActiveWindow(block: (AccessibilityNodeInfo?) -> Unit) {
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
     * Pianifica un re-check di [checkAppBlocking] per [pkg] al PROSSIMO confine
     * di una finestra oraria di un profilo TIME che lo targetizza.
     *
     * Risolve il caso "confine attraversato mentre l'utente è già dentro":
     * i TYPE_WINDOW_STATE_CHANGED scattano solo all'apertura/cambio app, quindi
     * una finestra che INIZIA (es. 14:00) mentre [pkg] è in foreground non
     * bloccherebbe mai finché l'utente non genera un nuovo evento. Allo scadere,
     * se l'utente è ancora dentro ([lastForegroundPackage] == pkg), rilancia
     * checkAppBlocking che — ora dentro la finestra — blocca; restando in Allow
     * ri-arma il confine successivo (catena auto-perpetuante). Se l'utente è
     * uscito, no-op (al rientro scatterà spontaneamente checkAppBlocking).
     *
     * Stesso pattern di [scheduleLimitCheck]. Considera solo i profili abilitati,
     * non in pausa indeterminata, di tipo TIME e attivi OGGI ([currentDayFlag]):
     * gli altri non hanno confini orari rilevanti per pkg.
     */
    private fun scheduleNextWindowBoundaryCheck(pkg: String, snapshot: ProfilesSnapshot) {
        pendingWindowBoundaryChecks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }

        val todayFlag = currentDayFlag()
        val intervals = snapshot.profiles.asSequence()
            .filter { p ->
                p.isEnabled &&
                    p.pausedUntil >= 0 &&
                    (p.typeCombinations and PROFILE_TYPE_TIME) != 0 &&
                    (p.dayFlags and todayFlag) != 0 &&
                    snapshot.profileApps[p.id]?.any { it.packageName == pkg && it.isEnabled } == true
            }
            .flatMap { (snapshot.profileIntervals[it.id] ?: emptyList()).asSequence() }
            .toList()
        if (intervals.isEmpty()) return

        val delayMin =
            BlockPolicyEvaluator.minutesUntilNextBoundary(currentMinutesOfDay(), intervals) ?: return

        val r = object : Runnable {
            override fun run() {
                // Service hygiene: skip se il service e' stato distrutto.
                if (instance != this@KoruAccessibilityService) return
                pendingWindowBoundaryChecks.remove(pkg)
                if (lastForegroundPackage != pkg) {
                    Log.d(TAG, "Window-boundary re-check for $pkg: user not there (foreground=$lastForegroundPackage)")
                    return
                }
                Log.i(TAG, "Window boundary reached for $pkg, re-evaluating")
                checkAppBlocking(pkg, profilesSnapshot.get())
            }
        }
        pendingWindowBoundaryChecks[pkg] = r
        // +1s di grace per cadere sicuri DENTRO la finestra: isNowInInterval è
        // half-open [from, to), a (from - 1s) saremmo ancora fuori.
        mainHandler.postDelayed(r, delayMin * 60_000L + 1_000L)
        Log.d(TAG, "Scheduled window-boundary re-check for $pkg in ${delayMin}min")
    }

    private fun cancelWindowBoundaryCheck(pkg: String) {
        pendingWindowBoundaryChecks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }
    }

    /**
     * Pianifica un RE-CHECK di [checkAppBlocking] per [pkg] dopo che il
     * ghost-guard ne ha scartato l'evento finestra.
     *
     * Risolve la race "ingresso genuino scartato come ghost": su un
     * quick-switch (o tap su notifica) verso un'app bloccata, l'evento
     * TYPE_WINDOW_STATE_CHANGED dell'app target può arrivare PRIMA che
     * UsageStats flushi il suo ACTIVITY_RESUMED — ForegroundDetector vede
     * ancora l'app precedente come foreground reale e il guard classifica
     * l'evento come ghost di uscita. Dentro l'app non arrivano altri window
     * event, quindi una singola decisione sbagliata sblocca l'INTERA sessione
     * (osservato on-device: WhatsApp→Instagram subito dopo l'unlock).
     *
     * Allo scadere ri-legge UsageStats (a flush ormai avvenuto):
     *  - foreground reale == [pkg] → l'evento era genuino: rilancia
     *    checkAppBlocking con overAppIfBlocked=true (l'utente è GIÀ dentro,
     *    stessa semantica del re-check post-unlock di [handleUserPresent]:
     *    overlay sopra l'app, niente kick).
     *  - foreground reale != [pkg] al primo giro → ritenta una volta a
     *    [GHOST_RECHECK_RETRY_DELAY_MS] (il flush può laggare oltre il primo
     *    delay sotto carico, es. animazione di unlock).
     *  - ancora diverso al secondo giro → era davvero un ghost: no-op.
     *
     * Anti-loop: il checkAppBlocking rilanciato ri-esegue il ghost-guard, che
     * a quel punto vede foreground == pkg e procede alla valutazione vera. Un
     * evento genuino sopravvenuto nel frattempo cancella il re-check pendente
     * (vedi hook nel guard), quindi niente doppia valutazione.
     *
     * Stesso pattern di [scheduleBackFallbackHome] / [scheduleLimitCheck].
     */
    /// STRUMENTAZIONE: logga su BlackBox (tag A11Y-FLASH) il ritardo
    /// evento→decisione di blocco. Chiamata all'ingresso di ciascun ramo di
    /// blocco. dt ~800ms ⇒ decisione arrivata dal ghost-recheck differito;
    /// dt di pochi ms ⇒ blocco sincrono. Consuma (rimuove) il timestamp.
    private fun logFlashDecision(pkg: String, reason: BlockReason) {
        val t0 = blockTriggerUptimeMs.remove(pkg) ?: return
        val delivery = blockTriggerDeliveryMs.remove(pkg) ?: -1L
        BlackBox.log(
            "A11Y-FLASH",
            "decision pkg=$pkg reason=$reason delivery=${delivery}ms " +
                "evt→decision=${SystemClock.uptimeMillis() - t0}ms",
        )
    }

    private fun scheduleGhostRecheck(pkg: String) {
        pendingGhostRechecks.remove(pkg)?.let { mainHandler.removeCallbacks(it) }
        val r = object : Runnable {
            private var attempt = 0
            override fun run() {
                // Service hygiene: skip se il service e' stato distrutto.
                if (instance != this@KoruAccessibilityService) return
                val fg = ForegroundDetector.detect(applicationContext)?.primaryPackage
                if (fg == pkg) {
                    pendingGhostRechecks.remove(pkg)
                    Log.i(TAG, "Ghost re-check: $pkg IS the real foreground → re-evaluating")
                    BlackBox.log("A11Y", "ghost re-check: $pkg è foreground reale → re-evaluate")
                    checkAppBlocking(pkg, profilesSnapshot.get(), overAppIfBlocked = true)
                    return
                }
                if (attempt == 0) {
                    attempt = 1
                    mainHandler.postDelayed(this, GHOST_RECHECK_RETRY_DELAY_MS)
                    return
                }
                pendingGhostRechecks.remove(pkg)
                blockTriggerUptimeMs.remove(pkg) // ghost reale: scarta i timestamp flash
                blockTriggerDeliveryMs.remove(pkg)
                Log.d(TAG, "Ghost re-check: $pkg never became foreground (fg=$fg) — real ghost")
            }
        }
        pendingGhostRechecks[pkg] = r
        mainHandler.postDelayed(r, GHOST_RECHECK_DELAY_MS)
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
        // Dedicato BYPASS_EXPIRED: discrimina nel log analytics da un normale
        // APP block (era loggato come restrictionType=0).
        BlockEventLogger.logRestrictedAccess(
            applicationContext,
            pkg,
            eventType = 0, // TRIGGERED
            restrictionType = RESTRICTION_TYPE_BYPASS_EXPIRED,
            timestamp = System.currentTimeMillis(),
        )
    }

    /**
     * Ritorna true se ha bloccato l'app (overlay mostrato + HOME).
     *
     * [overAppIfBlocked]: per i re-check di un'app GIÀ in foreground (unlock
     * su app resumed, vedi [handleUserPresent]) un eventuale blocco di
     * profilo usa la modalità overlay-over-app invece del kick-out: l'utente
     * non ha "aperto" nulla, l'app era già lì — va lasciata sotto l'overlay
     * finché non decide lui ("Don't open" = HOME duro, "Open anyway" =
     * dismiss e l'app continua da dov'era). Stessa famiglia UX del blocco
     * pre-lancio e del deep-link. Focus/limite restano blocchi "duri" che
     * espellono anche con questo flag (scelta deliberata di quei rami).
     */
    private fun checkAppBlocking(
        packageName: String,
        snapshot: ProfilesSnapshot = profilesSnapshot.get(),
        overAppIfBlocked: Boolean = false,
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
        // Side-effect (lettura UsageStats) qui; la DECISIONE e' delegata alla
        // funzione pura [GhostEventFilter.isGhostEvent] (ARCH-05). Stessa
        // condizione di prima: foreground reale noto, diverso dal pkg e non-skip.
        val foregroundDetected = ForegroundDetector
            .detect(applicationContext)?.primaryPackage
        if (GhostEventFilter.isGhostEvent(
                eventPackage = packageName,
                realForegroundPackage = foregroundDetected,
                isRealForegroundSkippable = foregroundDetected != null &&
                    SKIP_PACKAGES.contains(foregroundDetected),
            )
        ) {
            Log.d(
                TAG,
                "checkAppBlocking: pkg=$packageName but real foreground=" +
                    "$foregroundDetected (ghost transition event) — skip",
            )
            // Lo skip puo' essere un FALSO ghost: su quick-switch/notifica
            // l'evento dell'app target arriva prima che UsageStats flushi il
            // suo RESUMED (il foreground "reale" e' ancora l'app precedente).
            // Senza re-check l'intera sessione resterebbe sbloccata — dentro
            // l'app non arrivano altri window event. Il re-check differito
            // discrimina a flush avvenuto: vero ghost → no-op.
            scheduleGhostRecheck(packageName)
            return false
        }

        // Evento genuino: un re-check ghost pendente per questo pkg e' superato
        // da questa valutazione (evitiamo doppio overlay / doppio log quando il
        // runnable scatterebbe a blocco gia' applicato).
        pendingGhostRechecks.remove(packageName)?.let { mainHandler.removeCallbacks(it) }

        // Un evento app REALE (superato il ghost-guard) rende obsoleto lo stato
        // "pre-lancio": l'app è ora davvero in foreground — aperta dall'esterno
        // o appena lanciata da "Open anyway". Da qui vale la semantica di blocco
        // "duro" classica ("Don't open" → kick), non quella pre-lancio (dismiss
        // only). Vedi [showPreLaunchBlockIfNeeded] / [preLaunchOverlayPackage].
        preLaunchOverlayPackage = null

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
        // Se eravamo in overlay-over-app per un package DIVERSO, l'utente è
        // passato altrove (evento genuino, non ghost: il guard sopra l'ha già
        // filtrato): quella sessione over-app è finita → rilascia il focus audio
        // e azzera il tracking, così non resta "appiccicato" al pkg precedente.
        overlayOverAppPackage?.let { if (it != packageName) endOverlayOverApp() }

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
                    logFlashDecision(packageName, BlockReason.FOCUS_MODE)
                    Log.w(TAG, ">>> BLOCKING APP (focus): $packageName")
                    // Un focus/limite/sezione sopravvenuto è un blocco "duro" che
                    // espelle: chiude l'eventuale sessione over-app dello stesso pkg.
                    endOverlayOverApp()
                    currentlyBlockingPackage = packageName
                    val appLabel = getAppLabel(packageName)
                    // Reveal INLINE (siamo già sul main thread) e PRIMA di
                    // performGoHomeForBlock: l'overlay è attaccato prima che parta
                    // HOME/BACK e ne maschera la transizione. Il vecchio
                    // mainHandler.post riaccodava lo show in coda al looper, quindi
                    // GLOBAL_ACTION_HOME (sincrono) partiva prima del primo pixel.
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = decision.profileTitle,
                        reason = BlockReason.FOCUS_MODE,
                        config = OverlayConfig.DEFAULT,
                        profileEmoji = decision.profileEmoji,
                    )
                    // FOCUS_MODE: forceHome=true. La user-intent del Pomodoro /
                    // focus session è uscire dall'app, non navigare lo stack
                    // interno. BACK su un'app con activity nested chiuderebbe
                    // solo l'inner activity e l'app resterebbe in foreground.
                    performGoHomeForBlock(forceHome = true, blockedPackage = packageName)
                    val now = System.currentTimeMillis()
                    BlockEventLogger.logBlockSessionAndAccess(
                        applicationContext,
                        sessionName = packageName,
                        packageName = packageName,
                        restrictionType = BlockingContract.RESTRICTION_TYPE_FOCUS_MODE,
                        timestamp = now,
                    )
                    return true
                }

                BlockReason.USAGE_LIMIT -> {
                    logFlashDecision(packageName, BlockReason.USAGE_LIMIT)
                    Log.w(TAG, ">>> BLOCKING APP (daily limit, strict=${decision.isStrictLimit}): " +
                        "$packageName ${decision.todayMs / 60_000}min used, cap=${limitMinutes}min")
                    // Il cap è un blocco "duro" che espelle: chiude l'eventuale
                    // sessione over-app dello stesso pkg (rilascia il focus audio).
                    endOverlayOverApp()
                    currentlyBlockingPackage = packageName
                    cancelLimitCheck(packageName)
                    cancelWindowBoundaryCheck(packageName)
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
                    // Reveal INLINE prima di performGoHomeForBlock (vedi FOCUS_MODE).
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = decision.profileTitle,
                        reason = BlockReason.USAGE_LIMIT,
                        config = overlayConfig,
                        profileEmoji = decision.profileEmoji,
                        bypassPolicy = policy,
                    )
                    performGoHomeForBlock(blockedPackage = packageName)
                    val now = System.currentTimeMillis()
                    BlockEventLogger.logRestrictedAccess(
                        applicationContext,
                        packageName,
                        eventType = 0,
                        restrictionType = BlockingContract.RESTRICTION_TYPE_USAGE_LIMIT,
                        timestamp = now,
                    )
                    return true
                }

                else -> { // APP_BLOCKED (gli altri reason non sono raggiungibili qui)
                    logFlashDecision(packageName, BlockReason.APP_BLOCKED)
                    val profile = snapshot.profiles.firstOrNull { it.id == decision.profileId }
                    currentlyBlockingPackage = packageName
                    cancelWindowBoundaryCheck(packageName)

                    // Evento RIPETUTO durante una sessione overlay-over-app già
                    // attiva per questo pkg: l'app resta in foreground sotto
                    // l'overlay e ri-emette eventi. Overlay già su + audio già in
                    // pausa → no-op (evitiamo anche di ri-loggare/ri-emettere il
                    // blocco a ogni evento, cosa che il kick-out classico non fa
                    // perché dopo HOME l'app esce dal foreground).
                    if (overlayOverAppPackage == packageName) return true

                    val appLabel = getAppLabel(packageName)
                    val config = OverlayConfig.fromJsonString(decision.relation?.overlayConfigJson)
                    // Reveal INLINE prima della scelta kick/over-app + go-home
                    // (vedi FOCUS_MODE): l'overlay maschera subito, poi decidiamo
                    // se espellere o restare sopra l'app.
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = decision.profileTitle,
                        reason = BlockReason.APP_BLOCKED,
                        config = config,
                        profileEmoji = decision.profileEmoji,
                    )

                    // Modalità del blocco — "da link/altra app" vs "da icona del
                    // launcher" — decisa dall'app immediatamente precedente
                    // (UsageStats, authoritative anche per app fuori dal watched-set):
                    //  - launcher / Koru / nessuna  → apertura DIRETTA dall'icona →
                    //    blocco "duro" classico: espulsione alla home (BACK→HOME);
                    //  - un'app REALE (es. WhatsApp) → apertura da link/share/altra
                    //    app → overlay SOPRA l'app, NIENTE espulsione: così "Apri
                    //    comunque" si limita a dismissare e rivela esattamente il
                    //    deep link (il video YouTube), invece di rilanciare l'app
                    //    alla home perdendolo. Durante il countdown mettiamo in
                    //    pausa il media dell'app sotto (focus audio).
                    // [overAppIfBlocked] forza la modalità over-app a prescindere
                    // da cameFrom: usato dal re-check post-unlock, dove l'app era
                    // già in foreground (resumed, non "aperta") e cameFrom
                    // riporterebbe il launcher di un'apertura ormai storica.
                    val cameFrom = ForegroundDetector.previousForegroundPackage(applicationContext, packageName)
                    val openedFromOtherApp = cameFrom != null &&
                        cameFrom != applicationContext.packageName &&
                        !SKIP_PACKAGES.contains(cameFrom)
                    if (openedFromOtherApp || overAppIfBlocked) {
                        val why = if (openedFromOtherApp) "opened from '$cameFrom'" else "resumed re-check"
                        Log.w(TAG, ">>> BLOCKING APP (overlay-over-app, $why): " +
                            "$packageName by '${decision.profileTitle}'")
                        overlayOverAppPackage = packageName
                        requestMediaPause()
                    } else {
                        Log.w(TAG, ">>> BLOCKING APP: $packageName by '${decision.profileTitle}'")
                        performGoHomeForBlock(blockedPackage = packageName)
                    }
                    val now = System.currentTimeMillis()
                    BlockEventLogger.logBlockSessionAndAccess(
                        applicationContext,
                        sessionName = packageName,
                        packageName = packageName,
                        restrictionType = BlockingContract.RESTRICTION_TYPE_APP,
                        timestamp = now,
                    )
                    if (profile != null) BlockEventLogger.emitBlockingState(true, packageName, profile)
                    return true
                }
            }

            is BlockDecision.Allow -> {
                // STRUMENTAZIONE: decisione non-blocco → scarta i timestamp flash.
                blockTriggerUptimeMs.remove(packageName)
                blockTriggerDeliveryMs.remove(packageName)
                // Questo pkg non è più bloccato ORA (bypass concesso o profilo non
                // più attivo): una eventuale sessione over-app per esso è finita →
                // rilascia il focus audio (il video riprende) e azzera il tracking.
                endOverlayOverApp()
                // Confine orario: se un profilo TIME blocca pkg in una finestra
                // FUTURA (es. ora 13:57, finestra 14:00-18:00), pianifica il
                // re-check al confine — altrimenti, restando dentro l'app senza
                // generare eventi, il blocco non scatterebbe fino al prossimo
                // window-state-change (bug osservato su Instagram).
                scheduleNextWindowBoundaryCheck(packageName, snapshot)
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
                    BlockEventLogger.emitBlockingState(false, "", null)
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

    /**
     * GATE PRE-LANCIO per le aperture dall'UI di Koru (icona launcher/drawer/
     * favoriti/shortcut/swipe). Chiamato da [AppActionsCallHandler] PRIMA di
     * `startActivity`: se [packageName] sarebbe bloccato ORA, mostra l'overlay
     * di blocco SENZA aprire l'app e ritorna `true` → il chiamante NON lancia
     * l'intent. Così la UX diventa tap-icona → overlay → (Open anyway: apre /
     * Don't open: resta chiuso), eliminando il vecchio apri→espelli→riapri.
     *
     * L'overlay è IDENTICO a quello del path event-driven (stessa
     * [OverlayManager], stesso styling/font): non duplichiamo UI. I callback
     * esistenti gestiscono il resto, SENZA modifiche:
     *  - "Open anyway" → [OverlayManager.onBypassOpen]: l'app non è in
     *    foreground (reason ≠ BYPASS_EXPIRED, niente overlay-over-app) → ramo
     *    `!appStillForeground` → markBypassed + startActivity(launchIntent) =
     *    apre l'app per la prima volta (stessa grace di interazione del kick-out
     *    classico, qui per giunta Koru è in foreground);
     *  - "Don't open" → [OverlayManager.onReturnHome]: intercettato via
     *    [preLaunchOverlayPackage] → solo dismiss (niente BACK/HOME).
     *
     * Decisione DELEGATA a [BlockPolicyEvaluator] (single source of truth, come
     * checkAppBlocking e LockRunnable): focus → daily limit → bypass profilo →
     * profile loop. NESSUN side-effect di espulsione: l'app non è ancora aperta.
     *
     * Fail-safe: usa lo snapshot profili corrente senza forzare un reload
     * sul main thread (il tap resta reattivo). Una rara staleness degrada al
     * massimo al comportamento legacy — l'enforcement event-driven resta il
     * backstop autoritativo quando l'app effettivamente si apre. I limiti e il
     * focus sono letti FRESCHI dai rispettivi store (cross-process su file),
     * quindi non dipendono dalla freshness dello snapshot.
     *
     * Ritorna `false` (→ lancia normalmente) se non bloccato, se [packageName]
     * è Koru stessa / un pacchetto skip, o se non c'è overlay da mostrare.
     * Eseguito sul main thread (handler del MethodChannel `launchApp`).
     */
    fun showPreLaunchBlockIfNeeded(packageName: String): Boolean {
        if (packageName == this.packageName || SKIP_PACKAGES.contains(packageName)) return false
        // Fail-open: senza un overlay host non possiamo mostrare il blocco →
        // meglio lanciare l'app (l'enforcement event-driven la catturerà
        // all'apertura) che lasciare l'utente con né overlay né app aperta.
        if (overlayManager == null) return false

        val now = System.currentTimeMillis()
        val snapshot = profilesSnapshot.get()

        // Stesse letture d'ambiente di [checkAppBlocking] (tenere allineate):
        // focus (QuickBlockStore) e limite (AppUsageLimitsStore + contatore
        // guardato anti clock-backward) sono cross-process su file → freschi.
        val qbSnapshot = QuickBlockStore.read(applicationContext)
        val focusShouldBlock = qbSnapshot.shouldBlock(packageName, now)

        val limitEntry = AppUsageLimitsStore.entryFor(applicationContext, packageName)
        val limitMinutes = limitEntry?.minutes ?: 0
        val limitTodayMs = if (limitMinutes > 0) {
            UsageCounter.guardedTodayForegroundMs(applicationContext, packageName)
        } else 0L
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

        val block = decision as? BlockDecision.Block ?: return false

        val appLabel = getAppLabel(packageName)
        currentlyBlockingPackage = packageName
        preLaunchOverlayPackage = packageName

        // Per reason: stesso overlay + stesso logging del path event-driven
        // (checkAppBlocking), ma SENZA performGoHomeForBlock (l'app non è aperta)
        // e senza la discriminazione over-app (un'apertura da icona non è mai
        // "da link"). Se l'utente farà "Open anyway" verrà loggato anche lo
        // SKIPPED in onBypassOpen, esattamente come nel flusso classico.
        when (block.reason) {
            BlockReason.USAGE_LIMIT -> {
                val limitRelation = snapshot.profileApps.values.asSequence()
                    .flatten()
                    .firstOrNull { it.packageName == packageName }
                val limitBaseConfig = OverlayConfig.fromJsonString(limitRelation?.overlayConfigJson)
                val (overlayConfig, policy) = OverlayPolicies.buildUsageLimitOverlay(
                    applicationContext,
                    packageName,
                    baseConfig = limitBaseConfig,
                    isStrict = block.isStrictLimit,
                )
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = block.profileTitle,
                        reason = BlockReason.USAGE_LIMIT,
                        config = overlayConfig,
                        profileEmoji = block.profileEmoji,
                        bypassPolicy = policy,
                    )
                }
                BlockEventLogger.logRestrictedAccess(
                    applicationContext,
                    packageName,
                    eventType = 0,
                    restrictionType = BlockingContract.RESTRICTION_TYPE_USAGE_LIMIT,
                    timestamp = now,
                )
            }

            BlockReason.FOCUS_MODE -> {
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = block.profileTitle,
                        reason = BlockReason.FOCUS_MODE,
                        config = OverlayConfig.DEFAULT,
                        profileEmoji = block.profileEmoji,
                    )
                }
                BlockEventLogger.logBlockSessionAndAccess(
                    applicationContext,
                    sessionName = packageName,
                    packageName = packageName,
                    restrictionType = BlockingContract.RESTRICTION_TYPE_FOCUS_MODE,
                    timestamp = now,
                )
            }

            else -> { // APP_BLOCKED (WEBSITE/SECTION non raggiungibili da query per-app)
                val profile = snapshot.profiles.firstOrNull { it.id == block.profileId }
                val config = OverlayConfig.fromJsonString(block.relation?.overlayConfigJson)
                mainHandler.post {
                    overlayManager?.show(
                        packageName = packageName,
                        appLabel = appLabel,
                        profileTitle = block.profileTitle,
                        reason = BlockReason.APP_BLOCKED,
                        config = config,
                        profileEmoji = block.profileEmoji,
                    )
                }
                BlockEventLogger.logBlockSessionAndAccess(
                    applicationContext,
                    sessionName = packageName,
                    packageName = packageName,
                    restrictionType = BlockingContract.RESTRICTION_TYPE_APP,
                    timestamp = now,
                )
                if (profile != null) BlockEventLogger.emitBlockingState(true, packageName, profile)
            }
        }

        Log.w(TAG, ">>> PRE-LAUNCH BLOCK: $packageName (${block.reason}) — overlay shown, app NOT opened")
        BlackBox.log("A11Y", "pre-launch block $packageName reason=${block.reason}")
        return true
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
        // Un blocco di sezione è "duro" (espelle): chiude l'eventuale sessione
        // over-app dello stesso pkg prima del kick-out.
        endOverlayOverApp()
        // SECTION_BLOCKED: forceHome=true. Bloccare una "sezione"
        // dentro un'app (es. Reels, Shorts) ha senso solo se l'app
        // viene effettivamente chiusa. BACK chiuderebbe solo la
        // sub-activity (es. il viewer Reels) e l'utente resterebbe
        // sulla home dell'app, libero di tornare immediatamente
        // sulla sezione bloccata.
        performGoHomeForBlock(forceHome = true, blockedPackage = packageName)
        BlockEventLogger.logBlockSessionAndAccess(
            applicationContext,
            sessionName = "$packageName/${detected.wireId}",
            packageName = packageName,
            restrictionType = BlockingContract.RESTRICTION_TYPE_SECTION,
            timestamp = now,
        )
        if (profile != null) BlockEventLogger.emitSection(packageName, detected.wireId, profile)
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
            BlockEventLogger.logBlockSessionAndAccess(
                applicationContext,
                sessionName = detected.domain,
                packageName = packageName,
                restrictionType = BlockingContract.RESTRICTION_TYPE_WEBSITE,
                timestamp = now,
            )
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
            //
            // Le query + l'assemblaggio dello snapshot vivono in
            // [ProfileSnapshotLoader] (ARCH-05). Stesso ordine di fetch e stessa
            // costruzione immutabile di prima → swap atomico qui sotto: letture
            // concorrenti vedono o il vecchio o il nuovo snapshot, mai uno stato
            // parziale (finestra esistente nel pattern precedente di clear()+put()).
            val snapshot = ProfileSnapshotLoader.load(applicationContext)
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

    /// `false` finche' [applyDynamicPackageFilter] non ha applicato almeno una
    /// volta. Serve perche' il memo `watched == lastWatchedPackages` da solo
    /// salterebbe la PRIMA applicazione quando e' watch-all (`null == null`,
    /// stato iniziale): senza questo flag un focus attivo all'avvio del service
    /// non imposterebbe `packageNames = null`.
    @Volatile
    private var filterInitialized = false

    private fun applyDynamicPackageFilter(snapshot: ProfilesSnapshot) {
        try {
            // Focus / quick-block e' CATCH-ALL ("blocca tutto tranne whitelist"):
            // durante una sessione attiva OGNI app va valutata, quindi osserviamo
            // tutto (`packageNames = null`). La whitelist la applica l'evaluator
            // (BlockReason.FOCUS_MODE), non il filtro. Senza questo, un'app fuori
            // dal watched-set (no profilo, no limite, no browser/settings) non
            // genererebbe eventi e il focus non la bloccherebbe.
            val focusActive = QuickBlockStore.read(applicationContext).isSessionActiveNow()
            // `null` = watch-all (catch-all focus). Altrimenti il set ristretto:
            // i daily limit sono GLOBALI (non profile-scoped), quindi un'app con
            // cap attivo resta osservata anche se non e' in alcun profilo. Letture
            // nel percorso loadProfiles (gia' I/O DB, throttled) — non sul hot path.
            val watched: Set<String>? = if (focusActive) {
                null
            } else {
                val limitPackages = AppUsageLimitsStore.read(applicationContext)
                    .filterValues { it.minutes > 0 }
                    .keys
                WatchedPackageCalculator.calculate(
                    profileApps = snapshot.profileApps,
                    limitPackages = limitPackages,
                    knownBrowsers = KNOWN_BROWSERS,
                    settingsPackages = SETTINGS_PACKAGES,
                    skipPackages = SKIP_PACKAGES,
                    selfPackage = packageName,
                )
            }
            // Skip se il set non e' cambiato: ricreare AccessibilityServiceInfo
            // forza il system_server a re-validare il manifest e re-bindare
            // il service — operazione non gratuita, va evitata se inutile.
            if (watched == lastWatchedPackages && filterInitialized) return
            val info = serviceInfo ?: return
            // Modifichiamo in place i soli campi mutabili (packageNames).
            // canRetrieveWindowContent e' read-only sull'oggetto e proviene
            // dal manifest config XML — preservato implicitamente dato che
            // riutilizziamo l'istanza esistente. Creare un nuovo
            // AccessibilityServiceInfo from scratch perderebbe quel flag e
            // il system_server lo ri-validerebbe via meta-data.
            // null/empty ⇒ `packageNames = null` (ricevi da tutti = watch-all).
            info.packageNames = if (watched.isNullOrEmpty()) null else watched.toTypedArray()
            serviceInfo = info
            lastWatchedPackages = watched
            filterInitialized = true
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
        BlackBox.log("A11Y", "onDestroy — accessibility service distrutto (possibile kill OEM o teardown processo)")
        instance = null
        actionReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        actionReceiver = null
        screenStateReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        screenStateReceiver = null
        pendingBypassExpiryChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingBypassExpiryChecks.clear()
        pendingLimitChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingLimitChecks.clear()
        pendingWindowBoundaryChecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingWindowBoundaryChecks.clear()
        pendingBackFallbacks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingBackFallbacks.clear()
        pendingGhostRechecks.values.forEach { mainHandler.removeCallbacks(it) }
        pendingGhostRechecks.clear()
        LauncherRecentsGate.onServiceDestroyed()
        lastBypassedActiveForeground = null
        preLaunchOverlayPackage = null
        endOverlayOverApp()
        overlayManager?.destroy()
        overlayManager = null
        NativeDatabase.close()
        super.onDestroy()
    }
}

/// True se l'app correntemente in foreground NON coincide col target dell'overlay,
/// ossia il click su "Don't open" sta arrivando con l'overlay "stale" sopra un'app
/// innocente. Usato dal callback onReturnHome per evitare di eseguire BACK/HOME su
/// un foreground che non e' la app per cui l'overlay e' stato creato (caso classico:
/// lock + apertura WhatsApp da notification trampoline lascia overlay stale di
/// Instagram sopra WhatsApp).
///
/// Precedenza:
///  1. realForegroundPackage (UsageStats authoritative quando disponibile).
///  2. accessibilityForegroundPackage (ultimo TYPE_WINDOW_STATE_CHANGED visto).
///  3. Entrambi null/unknown → trust-the-system (non-stale, procediamo col path
///     normale). Una "mancata difesa" e' meno invasiva di una "falsa difesa" che
///     ignora il click di un utente realmente sull'app bloccata.
internal fun isStaleOverlayClick(
    targetPackage: String,
    realForegroundPackage: String?,
    accessibilityForegroundPackage: String?,
): Boolean {
    if (targetPackage.isEmpty()) return false
    if (realForegroundPackage != null) return realForegroundPackage != targetPackage
    if (accessibilityForegroundPackage != null) {
        return accessibilityForegroundPackage != targetPackage
    }
    return false
}
