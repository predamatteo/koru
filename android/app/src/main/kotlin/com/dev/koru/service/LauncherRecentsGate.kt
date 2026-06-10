package com.dev.koru.service

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.dev.koru.diagnostics.BlackBox

/// Blocco della gesture di sistema "apri recents" (swipe-up-and-hold) SCOPATO
/// al launcher Koru. Android riserva la striscia mandatory in basso: la
/// gesture NON è escludibile via setSystemGestureExclusionRects (vedi
/// [com.dev.koru.channels.PermissionMethodChannel]), quindi l'unico blocco
/// affidabile è rilevare la finestra recents appena appare e richiuderla
/// (flash di ~100-300ms accettato dal design).
///
/// Stato (singleton in-memory: servizio a11y, channel handler e engine Flutter
/// vivono tutti nel processo MAIN — nessun android:process nel manifest):
///
/// - [shieldActive]: settato dal lato Dart via `setLauncherRecentsShield`,
///   cavalcando lo stesso lifecycle RouteAware dell'esclusione gesture
///   (didPush/didPopNext → ON, didPushNext/dispose → OFF). Il flag da solo
///   NON basta: RouteAware vede solo la navigazione Flutter — se l'utente
///   lancia un'altra app la route Dart resta /launcher. La correttezza la
///   porta il guard [computeCameFromKoru] (UsageStats). NON azzerare il flag
///   sul pause Dart: aprire le recents pausa MainActivity PRIMA che arrivi
///   l'evento finestra → il blocco non scatterebbe mai.
///
/// - allow-token ([noteAllowRequest]): emesso dal handler `openSystemRecents`
///   PRIMA di performGlobalAction(GLOBAL_ACTION_RECENTS). Uptime clock,
///   coerente con la postura anti-manipolazione di BypassStore. Consumato al
///   primo evento recents → [sessionAllowed].
///
/// - [sessionAllowed]: sticky e SENZA timeout — restare nelle recents >5s e
///   poi tappare un'app non deve produrre kick spurî (i kick scattano solo su
///   eventi recents, che la sessione assorbe). Chiusa da: prima finestra
///   reale non-recents, screen-off, onDestroy del service.
///
/// Precedenza strict mode: [handleEvent] è invocato DOPO
/// StrictModeEnforcer.handleEvent — con BLOCK_RECENT_APPS attivo strict kicka
/// e ritorna prima, quindi il token non può fare da bypass dello strict.
object LauncherRecentsGate {
    private const val TAG = "LauncherRecentsGate"
    internal const val ALLOW_TOKEN_MS = 5_000L

    /// Verify-before-kick: tra l'evento recents e il kick aspettiamo questo
    /// delay e ri-verifichiamo. Assorbe eventi recents transitori (es.
    /// quick-switch sul pill che su alcuni OEM resume-a brevemente
    /// RecentsActivity): al verify l'app target è già foreground → abort.
    private const val KICK_VERIFY_DELAY_MS = 250L

    /// Sanity-check della sessione: se l'utente esce dalle recents verso
    /// un'app FUORI dal watched-set dinamico, nessun window event arriva e la
    /// sessione (con typeViewClicked attivo) resterebbe appesa per ore. Questo
    /// timer ricontrolla il foreground reale e chiude la sessione orfana.
    private const val SESSION_SANITY_DELAY_MS = 60_000L

    /// Lookback a due stadi per la provenienza: prima una scansione corta
    /// (caso comune: uso attivo), poi il fallback lungo per l'utente rimasto
    /// fermo sul launcher a lungo prima dello swipe. Tutto su main thread
    /// (evento raro, precedente consolidato nel service) ma il caso comune
    /// paga solo la scansione corta.
    private const val PREV_FG_LOOKBACK_SHORT_MS = 300_000L
    private const val PREV_FG_LOOKBACK_LONG_MS = 3_600_000L

    internal enum class Decision {
        ALLOW_TOKEN, ALLOW_IN_SESSION, ALLOW_SHIELD_OFF, ALLOW_NOT_FROM_KORU, BLOCK,
    }

    @Volatile private var shieldActive = false
    @Volatile private var allowUntilUptimeMs = 0L
    @Volatile private var sessionAllowed = false
    @Volatile private var recentsVisible = false

    // Lazy: l'object viene caricato anche dai unit test JVM (per [decide]),
    // dove Looper non esiste — l'handler serve solo a runtime per il kick.
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    /// Accesso confinato al main thread (callback a11y + channel handler).
    private var pendingKick: Runnable? = null
    private var pendingSessionSanity: Runnable? = null

    fun setShieldActive(active: Boolean) {
        if (shieldActive == active) return
        shieldActive = active
        BlackBox.log("RECENTS", "shield ${if (active) "ON (launcher in cima)" else "OFF"}")
    }

    /// Da chiamare PRIMA di performGlobalAction(GLOBAL_ACTION_RECENTS) nel
    /// handler `openSystemRecents`. Se le recents poi non si aprono, il token
    /// scade da solo (innocuo). Evento arrivato oltre i 5s (device lentissimo):
    /// un kick verso il launcher su cui l'utente già si trova — fail-safe.
    fun noteAllowRequest() {
        allowUntilUptimeMs = SystemClock.uptimeMillis() + ALLOW_TOKEN_MS
        BlackBox.log("RECENTS", "allow-token emesso (apertura via icona launcher)")
    }

    /// Chiamato da onAccessibilityEvent DOPO StrictModeEnforcer.handleEvent e
    /// PRIMA del return SKIP_PACKAGES (l'host delle recents È nello skip-set).
    /// Ritorna true se l'evento è una finestra recents (gestita qui, in un
    /// senso o nell'altro); false per tutto il resto (flusso normale).
    fun handleEvent(service: KoruAccessibilityService, event: AccessibilityEvent): Boolean {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return false
        val pkg = event.packageName?.toString() ?: return false
        val className = event.className?.toString() ?: ""

        val isRecents = RecentsDetector.isRecentsHostWindow(
            packageName = pkg,
            className = className,
            selfPackage = service.packageName,
            skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
        )
        if (!isRecents) {
            // Finestra REALE non-recents: chiude la sessione e annulla un
            // eventuale kick pending (quick-switch commit-ato sull'app
            // target). Esclusi i ghost del framework (pkg "android"/className
            // vuoto) E systemui: la shade/QS/volume hanno window event con
            // pkg systemui ma NON significano "recents chiusa" — un pull
            // della shade nei 250ms del verify cancellerebbe un kick
            // legittimo (vettore di bypass) o chiuderebbe una sessione
            // allowed a metà (falso kick alla re-emissione successiva).
            if (className.isNotEmpty() && pkg != "android" && pkg != "com.android.systemui") {
                onNonRecentsWindow(service, pkg)
            }
            return false
        }

        if (!recentsVisible) {
            recentsVisible = true
            // Clear-all detection: typeViewClicked SOLO a sessione attiva —
            // stesso pattern di mutazione in-place di applyDynamicPackageFilter,
            // costo limitato ai secondi in cui le recents sono aperte.
            setClickEventsEnabled(service, true)
            scheduleSessionSanityCheck(service)
        }

        val tokenValid = SystemClock.uptimeMillis() <= allowUntilUptimeMs
        // computeCameFromKoru fa query UsageStats: valutato SOLO quando le
        // condizioni economiche non hanno già deciso (evento recents = raro).
        val decision = if (tokenValid || sessionAllowed || !shieldActive) {
            decide(tokenValid, sessionAllowed, shieldActive, cameFromKoru = false)
        } else {
            decide(tokenValid, sessionAllowed, shieldActive, computeCameFromKoru(service, pkg))
        }

        when (decision) {
            Decision.ALLOW_TOKEN -> {
                allowUntilUptimeMs = 0L // consumato
                sessionAllowed = true
                BlackBox.log("RECENTS", "recents aperta via token → sessione allowed")
            }
            Decision.ALLOW_IN_SESSION -> { /* re-emissione interna alle recents */ }
            Decision.ALLOW_SHIELD_OFF, Decision.ALLOW_NOT_FROM_KORU -> {
                sessionAllowed = true
                BlackBox.log(
                    "RECENTS",
                    "recents allowed ($decision): aperta fuori dal launcher Koru",
                )
            }
            Decision.BLOCK -> scheduleVerifiedKick(service, pkg, className)
        }
        return true
    }

    /// Matrice di decisione PURA (unit-testabile). Ordine dei guard:
    /// token > sessione > shield > provenienza.
    internal fun decide(
        tokenValid: Boolean,
        sessionAllowed: Boolean,
        shieldActive: Boolean,
        cameFromKoru: Boolean,
    ): Decision = when {
        tokenValid -> Decision.ALLOW_TOKEN
        sessionAllowed -> Decision.ALLOW_IN_SESSION
        !shieldActive -> Decision.ALLOW_SHIELD_OFF
        !cameFromKoru -> Decision.ALLOW_NOT_FROM_KORU
        else -> Decision.BLOCK
    }

    /// "Venivo dal launcher Koru quando le recents si sono aperte?"
    /// Doppio check UsageStats per coprire il lag di indicizzazione nei due
    /// versi (vedi ForegroundDetector.previousForegroundPackage): (1) il
    /// predecessore dell'host recents è Koru (RESUMED delle recents già
    /// indicizzato), oppure (2) il primary è ancora Koru (non ancora
    /// indicizzato). Lookback lungo: l'utente può restare fermo sul launcher
    /// per minuti prima dello swipe. Fail-OPEN (recents si apre) quando
    /// UsageStats non risponde — direzione di fallimento giusta per una
    /// feature UX, e coerente col resto del codice (bypass-revoke).
    private fun computeCameFromKoru(
        service: KoruAccessibilityService,
        recentsPkg: String,
    ): Boolean {
        val self = service.packageName
        val ctx = service.applicationContext
        val prev = try {
            ForegroundDetector.previousForegroundPackage(
                ctx, recentsPkg, lookbackMs = PREV_FG_LOOKBACK_SHORT_MS,
            ) ?: ForegroundDetector.previousForegroundPackage(
                ctx, recentsPkg, lookbackMs = PREV_FG_LOOKBACK_LONG_MS,
            )
        } catch (_: Exception) {
            null
        }
        if (prev == self) return true
        if (prev != null) return false
        val primary = try {
            ForegroundDetector.detect(ctx)?.primaryPackage
        } catch (_: Exception) {
            null
        }
        return primary == self
    }

    private fun scheduleVerifiedKick(
        service: KoruAccessibilityService,
        pkg: String,
        className: String,
    ) {
        if (pendingKick != null) return
        BlackBox.log(
            "RECENTS",
            "gesture recents dal launcher: $pkg/$className → kick tra ${KICK_VERIFY_DELAY_MS}ms (verify)",
        )
        val r = Runnable {
            pendingKick = null
            // Igiene post-onDestroy (stesso guard degli altri delayed
            // runnable del service): un kick orfano su un service morto
            // sparerebbe comunque l'HOME intent e sporcherebbe lo stato
            // di un'eventuale istanza rebindata.
            if (KoruAccessibilityService.instance !== service) return@Runnable
            // Verify 1: foreground reale già un'app vera (≠ Koru, ≠ host
            // recents plausibile) → transizione/quick-switch commit-ata:
            // abort + chiusura sessione (le recents non sono più davanti).
            // NB: il predicato host è lo STESSO usato per classificare la
            // finestra come recents — usare solo SKIP_PACKAGES qui rendeva
            // il kick sempre abortito sugli OEM con host fuori dallo skip-set
            // (l'host stesso veniva classificato come "app reale").
            val fg = try {
                ForegroundDetector.detect(service.applicationContext)?.primaryPackage
            } catch (_: Exception) {
                null
            }
            val fgIsRealApp = fg != null && fg != service.packageName &&
                !RecentsDetector.isPlausibleRecentsHostPackage(
                    fg, KoruAccessibilityService.SKIP_PACKAGES,
                )
            if (fgIsRealApp) {
                BlackBox.log("RECENTS", "kick ABORT: foreground reale=$fg (transizione)")
                endSession(service)
                return@Runnable
            }
            // Verify 2: ri-check della provenienza. Il lag di indicizzazione
            // UsageStats può aver prodotto un BLOCK per uno swipe partito da
            // dentro un'app appena lanciata dal launcher (X non ancora
            // indicizzata al decision time): se ora la provenienza legge
            // non-launcher, le recents sono legittime → sessione allowed.
            if (!computeCameFromKoru(service, pkg)) {
                BlackBox.log("RECENTS", "kick ABORT: provenienza non-launcher al re-check")
                sessionAllowed = true
                return@Runnable
            }
            BlackBox.log("RECENTS", "kick: chiudo recents → HOME (launcher)")
            // NIENTE endSession preventiva: se goToHomeViaIntent coalizza
            // l'HOME (guard anti-loop 800ms) le recents restano aperte — con
            // lo stato sessione intatto una re-emissione recents ri-schedula
            // il kick (retry naturale). A kick riuscito è il window event di
            // ritorno al launcher a chiudere la sessione.
            // forceHome + suppressLauncherNavigationUntilMs: preserva la
            // sub-pagina del launcher Flutter (stesso helper dello strict).
            service.performGoHomeForBlock(forceHome = true)
        }
        pendingKick = r
        mainHandler.postDelayed(r, KICK_VERIFY_DELAY_MS)
    }

    private fun onNonRecentsWindow(service: KoruAccessibilityService, pkg: String) {
        pendingKick?.let {
            mainHandler.removeCallbacks(it)
            pendingKick = null
            BlackBox.log("RECENTS", "kick annullato: finestra reale $pkg prima del verify")
        }
        if (recentsVisible) {
            BlackBox.log("RECENTS", "sessione recents chiusa (foreground → $pkg)")
            endSession(service)
        }
    }

    /// Belt-and-suspenders per la sessione orfana: uscire dalle recents verso
    /// un'app FUORI dal watched-set dinamico non genera alcun window event →
    /// recentsVisible/sessionAllowed resterebbero appesi e typeViewClicked
    /// attivo per ore (e un click "clear"-like in un'app watched con
    /// "home"/"launcher" nel pkg potrebbe azzerare il contatore a sproposito).
    /// Ogni SESSION_SANITY_DELAY_MS verifichiamo il foreground reale: se non è
    /// più un host recents plausibile né Koru, la sessione è orfana → chiusa.
    private fun scheduleSessionSanityCheck(service: KoruAccessibilityService) {
        pendingSessionSanity?.let { mainHandler.removeCallbacks(it) }
        val r = object : Runnable {
            override fun run() {
                if (KoruAccessibilityService.instance !== service) return
                if (!recentsVisible) {
                    pendingSessionSanity = null
                    return
                }
                val fg = try {
                    ForegroundDetector.detect(service.applicationContext)?.primaryPackage
                } catch (_: Exception) {
                    null
                }
                val stillPlausible = fg == null || fg == service.packageName ||
                    RecentsDetector.isPlausibleRecentsHostPackage(
                        fg, KoruAccessibilityService.SKIP_PACKAGES,
                    )
                if (!stillPlausible) {
                    BlackBox.log("RECENTS", "sessione orfana chiusa dal sanity-check (fg=$fg)")
                    pendingSessionSanity = null
                    endSession(service)
                } else {
                    mainHandler.postDelayed(this, SESSION_SANITY_DELAY_MS)
                }
            }
        }
        pendingSessionSanity = r
        mainHandler.postDelayed(r, SESSION_SANITY_DELAY_MS)
    }

    private fun endSession(service: KoruAccessibilityService) {
        recentsVisible = false
        sessionAllowed = false
        pendingSessionSanity?.let {
            mainHandler.removeCallbacks(it)
            pendingSessionSanity = null
        }
        setClickEventsEnabled(service, false)
    }

    /// Click dentro le recents (consegnati solo a sessione attiva): rileva
    /// "Cancella tutto" → reset del contatore schede. Best-effort: gli id
    /// OEM variano; il fallback utente è il long-press sull'icona.
    fun onViewClicked(service: KoruAccessibilityService, event: AccessibilityEvent) {
        if (!recentsVisible) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == service.packageName) return
        if (!RecentsDetector.isPlausibleRecentsHostPackage(
                pkg, KoruAccessibilityService.SKIP_PACKAGES,
            )
        ) {
            return
        }
        // Il nodo source va riciclato pre-Tiramisu (caller-owned sotto API 33)
        // — stesso pattern di withRootInActiveWindow: i nodi non riciclati
        // saturano il buffer binder accessibility ("Suspicious node", fps drop).
        val src = try {
            event.source
        } catch (_: Exception) {
            null
        }
        try {
            val viewId = src?.viewIdResourceName
            val text = event.text?.filterNotNull()?.joinToString(" ")?.takeIf { it.isNotBlank() }
                ?: event.contentDescription?.toString()
            if (RecentsDetector.isClearAllNode(viewId, text)) {
                BlackBox.log("RECENTS", "\"Cancella tutto\" rilevato (id=$viewId) → reset contatore")
                OpenAppsTracker.resetAll(service.applicationContext)
            }
        } finally {
            if (src != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                @Suppress("DEPRECATION")
                try {
                    src.recycle()
                } catch (_: Throwable) {
                }
            }
        }
    }

    /// Hook da handleScreenOff: a schermo spento niente recents visibili —
    /// chiudi sessione, token e kick pending (un kick a schermo off è rumore).
    fun onScreenOff(service: KoruAccessibilityService) {
        pendingKick?.let {
            mainHandler.removeCallbacks(it)
            pendingKick = null
        }
        allowUntilUptimeMs = 0L
        if (recentsVisible) endSession(service)
    }

    /// Hook da onDestroy: serviceInfo non è più mutabile qui — il rebind del
    /// service ripristina da solo l'eventTypes del config XML (senza
    /// typeViewClicked), quindi basta azzerare lo stato in-memory. I runnable
    /// pending vanno RIMOSSI dalla queue (non solo nullati): un kick orfano
    /// post-destroy sparerebbe comunque l'HOME intent.
    fun onServiceDestroyed() {
        pendingKick?.let { mainHandler.removeCallbacks(it) }
        pendingKick = null
        pendingSessionSanity?.let { mainHandler.removeCallbacks(it) }
        pendingSessionSanity = null
        allowUntilUptimeMs = 0L
        sessionAllowed = false
        recentsVisible = false
    }

    /// Toggle dinamico di typeViewClicked su serviceInfo (mutazione in-place,
    /// stesso pattern e stesse cautele di applyDynamicPackageFilter: riusare
    /// l'istanza esistente preserva canRetrieveWindowContent e gli altri
    /// campi read-only del config XML).
    private fun setClickEventsEnabled(service: KoruAccessibilityService, enabled: Boolean) {
        try {
            val info = service.serviceInfo ?: return
            val want = if (enabled) {
                info.eventTypes or AccessibilityEvent.TYPE_VIEW_CLICKED
            } else {
                info.eventTypes and AccessibilityEvent.TYPE_VIEW_CLICKED.inv()
            }
            if (want == info.eventTypes) return
            info.eventTypes = want
            service.serviceInfo = info
        } catch (e: Exception) {
            Log.w(TAG, "toggle typeViewClicked fallito: ${e.message}")
        }
    }

    // ─── Solo per i test ─────────────────────────────────────────────────────

    internal fun debugResetState() {
        pendingKick = null
        pendingSessionSanity = null
        shieldActive = false
        allowUntilUptimeMs = 0L
        sessionAllowed = false
        recentsVisible = false
    }
}
