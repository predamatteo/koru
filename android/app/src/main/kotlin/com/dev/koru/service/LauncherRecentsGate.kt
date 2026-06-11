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
/// possibile è rilevare la finestra recents appena appare e dismissarla
/// IMMEDIATAMENTE (BACK sullo stesso callback dell'evento: la schermata
/// rimbalza a metà animazione — il "flash" residuo è la sola latenza di
/// consegna dell'evento, fisicamente incomprimibile per un'app non-system).
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

    /// Fallback del dismiss immediato: se dopo questo delay la sessione
    /// recents è ancora aperta (nessun window event di ritorno al launcher),
    /// il BACK non ha chiuso la schermata → forza HOME. Cancellato da
    /// [onNonRecentsWindow] quando il dismiss riesce.
    private const val KICK_FALLBACK_DELAY_MS = 500L

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

    /// Sync del contatore con le card reali delle recents: throttle dei
    /// content-changed (l'overview ne emette a raffica durante animazioni e
    /// scroll) + BURST di scansioni iniziali. Il burst (e non una singola
    /// scansione ritardata) è essenziale per le recents VUOTE: non emettono
    /// content-change e si auto-chiudono in ~650ms (misurato on-device) —
    /// una scansione sola a +550ms arrivava spesso a finestra già chiusa e
    /// lo stato "0 schede" non veniva mai letto (contatore inchiodato).
    /// Ogni scansione è protetta dal guard sul root (OpenAppsTracker): una
    /// partita troppo presto/tardi è un no-op, e un'eventuale lettura
    /// transitoria sbagliata viene corretta dalle successive del burst.
    private const val RECENTS_SCAN_THROTTLE_MS = 300L
    private const val RECENTS_INITIAL_SCAN_FIRST_DELAY_MS = 150L
    private const val RECENTS_INITIAL_SCAN_REPEAT_DELAY_MS = 250L
    private const val RECENTS_INITIAL_SCAN_ATTEMPTS = 3

    /// Margine del trailing scan oltre il residuo del throttle: lo scan
    /// differito parte appena FUORI dalla finestra, non sul bordo.
    private const val TRAILING_SCAN_MARGIN_MS = 50L

    /// Retry su scan ambiguo ("0 card mappate ma clear-all presente", vedi
    /// [OpenAppsTracker.RecentsSyncDecision.RetryLater]): delay breve — a
    /// fine animazione del clear il bottone è sparito — e budget per
    /// sessione: senza, una recents statica con label non mappate e
    /// clear-all visibile farebbe scan→retry→scan ogni 250ms a vita.
    private const val CLEAR_ALL_RETRY_DELAY_MS = 250L
    private const val CLEAR_ALL_RETRY_MAX_PER_SESSION = 2

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
    private var pendingInitialScan: Runnable? = null

    /// Slot UNICO per gli scan ritardati one-shot (trailing del throttle;
    /// dal fix clear-all anche il retry post-scan ambiguo): mai più di uno
    /// scan extra in coda oltre al burst — coalescenza sulla deadline più
    /// vicina in [requestDelayedScan].
    private var pendingOneShotScan: Runnable? = null
    private var pendingOneShotScanDueUptimeMs = 0L

    /// Retry residui per la sessione corrente (vedi CLEAR_ALL_RETRY_*).
    private var clearAllRetryBudget = 0

    @Volatile private var lastRecentsScanUptimeMs = 0L

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
        // Dismiss già in volo: le re-emissioni recents durante la chiusura
        // non devono ricomputare la provenienza (query UsageStats) né
        // accodare altri BACK (uno sparato a recents già chiuse colpirebbe
        // il launcher). Il token salta il filtro: un tap sull'icona vince.
        if (pendingKick != null && !tokenValid) return true
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
                BlackBox.log("RECENTS", "recents aperta via token → sessione allowed")
                onSessionAllowed(service)
            }
            Decision.ALLOW_IN_SESSION -> { /* re-emissione interna alle recents */ }
            Decision.ALLOW_SHIELD_OFF, Decision.ALLOW_NOT_FROM_KORU -> {
                BlackBox.log(
                    "RECENTS",
                    "recents allowed ($decision): aperta fuori dal launcher Koru",
                )
                onSessionAllowed(service)
            }
            Decision.BLOCK -> performImmediateKick(service, pkg, className)
        }
        return true
    }

    /// Sessione legittima appena aperta: arma il sync del contatore con le
    /// card reali. Prewarm della label map (off-main) + scansione iniziale
    /// ritardata — copre le recents VUOTE, che possono non emettere alcun
    /// content-change (è il caso "dice 1 app ma non c'è niente": senza
    /// scansione lo zero non verrebbe mai letto).
    private fun onSessionAllowed(service: KoruAccessibilityService) {
        val firstAllow = !sessionAllowed
        sessionAllowed = true
        if (!firstAllow) return
        OpenAppsTracker.prewarmLabelMap(service.applicationContext)
        clearAllRetryBudget = CLEAR_ALL_RETRY_MAX_PER_SESSION
        pendingInitialScan?.let { mainHandler.removeCallbacks(it) }
        val r = object : Runnable {
            private var attempt = 0
            override fun run() {
                pendingInitialScan = null
                if (KoruAccessibilityService.instance !== service) return
                if (!recentsVisible || !sessionAllowed) return
                performScan(service)
                attempt++
                if (attempt < RECENTS_INITIAL_SCAN_ATTEMPTS) {
                    pendingInitialScan = this
                    mainHandler.postDelayed(this, RECENTS_INITIAL_SCAN_REPEAT_DELAY_MS)
                }
            }
        }
        pendingInitialScan = r
        mainHandler.postDelayed(r, RECENTS_INITIAL_SCAN_FIRST_DELAY_MS)
    }

    /// Chiamato dal service sui TYPE_WINDOW_CONTENT_CHANGED / VIEW_SCROLLED:
    /// se arrivano dall'host recents durante una sessione legittima, throttla
    /// e ri-sincronizza il contatore (lo swipe-dismiss di una card cambia il
    /// contenuto senza altri segnali osservabili). Throttle leading+TRAILING:
    /// l'ULTIMO evento di una raffica è quello che porta lo stato finale —
    /// es. l'overview vuota dopo lo swipe dell'ultima card, che si
    /// auto-chiude ~650ms dopo: col solo leading-edge quell'evento veniva
    /// scartato e lo zero non veniva mai letto (badge inchiodato finché non
    /// si rientrava/usciva dalle recents). Ritorna true se l'evento
    /// appartiene alla schermata recents (consumato).
    fun maybeSyncOpenApps(service: KoruAccessibilityService, pkg: String): Boolean {
        if (!recentsVisible || !sessionAllowed) return false
        if (!RecentsDetector.isPlausibleRecentsHostPackage(
                pkg, KoruAccessibilityService.SKIP_PACKAGES,
            )
        ) {
            return false
        }
        val now = SystemClock.uptimeMillis()
        val decision = decideScanThrottle(
            nowUptimeMs = now,
            lastScanUptimeMs = lastRecentsScanUptimeMs,
            throttleMs = RECENTS_SCAN_THROTTLE_MS,
            scanAlreadyPending = pendingOneShotScan != null || pendingInitialScan != null,
        )
        when (decision) {
            ScanThrottle.SCAN_NOW -> {
                // Un one-shot ancora in coda sarebbe ridondante a pochi ms
                // dallo scan appena eseguito.
                cancelOneShotScan()
                performScan(service)
            }
            ScanThrottle.SCHEDULE_TRAILING -> requestDelayedScan(
                service,
                trailingScanDelayMs(
                    nowUptimeMs = now,
                    lastScanUptimeMs = lastRecentsScanUptimeMs,
                    throttleMs = RECENTS_SCAN_THROTTLE_MS,
                    marginMs = TRAILING_SCAN_MARGIN_MS,
                ),
            )
            ScanThrottle.ALREADY_PENDING -> {
                // Coalescenza: lo scan già in coda leggerà lo stato finale.
            }
        }
        return true
    }

    /// Esecuzione centralizzata di uno scan: TUTTE le sorgenti (burst
    /// iniziale, leading-edge, one-shot differiti) passano da qui, così
    /// [lastRecentsScanUptimeMs] — e quindi il throttle — resta onesto, e
    /// l'esito ambiguo (RETRY_SUGGESTED) arma un retry qualunque sia la
    /// sorgente dello scan.
    private fun performScan(service: KoruAccessibilityService): OpenAppsTracker.RecentsScanOutcome {
        lastRecentsScanUptimeMs = SystemClock.uptimeMillis()
        val outcome = OpenAppsTracker.syncFromRecents(service)
        if (outcome == OpenAppsTracker.RecentsScanOutcome.RETRY_SUGGESTED &&
            clearAllRetryBudget > 0
        ) {
            clearAllRetryBudget--
            requestDelayedScan(service, CLEAR_ALL_RETRY_DELAY_MS)
        }
        return outcome
    }

    /// Scan one-shot differito sullo slot unico [pendingOneShotScan]:
    /// se ce n'è già uno in coda vince la deadline più VICINA (un trailing
    /// non deve posticipare un retry già armato, e viceversa). Stessi guard
    /// di igiene degli altri runnable del gate.
    private fun requestDelayedScan(service: KoruAccessibilityService, delayMs: Long) {
        val due = SystemClock.uptimeMillis() + delayMs
        pendingOneShotScan?.let {
            if (pendingOneShotScanDueUptimeMs <= due) return
            mainHandler.removeCallbacks(it)
        }
        val r = Runnable {
            pendingOneShotScan = null
            pendingOneShotScanDueUptimeMs = 0L
            if (KoruAccessibilityService.instance !== service) return@Runnable
            if (!recentsVisible || !sessionAllowed) return@Runnable
            performScan(service)
        }
        pendingOneShotScan = r
        pendingOneShotScanDueUptimeMs = due
        mainHandler.postDelayed(r, delayMs)
    }

    private fun cancelOneShotScan() {
        pendingOneShotScan?.let { mainHandler.removeCallbacks(it) }
        pendingOneShotScan = null
        pendingOneShotScanDueUptimeMs = 0L
    }

    /// Esito PURO del throttle degli scan content-changed (vedi
    /// [maybeSyncOpenApps]).
    internal enum class ScanThrottle { SCAN_NOW, SCHEDULE_TRAILING, ALREADY_PENDING }

    /// Decisione PURA del throttle leading+trailing: fuori finestra → scan
    /// subito; dentro finestra con uno scan già in arrivo (one-shot O burst)
    /// → coalescenza; dentro finestra senza nulla in coda → trailing
    /// one-shot. Il pending NON sopprime lo SCAN_NOW: fuori finestra si
    /// scansiona comunque (è il wrapper a cancellare l'one-shot ridondante).
    internal fun decideScanThrottle(
        nowUptimeMs: Long,
        lastScanUptimeMs: Long,
        throttleMs: Long,
        scanAlreadyPending: Boolean,
    ): ScanThrottle = when {
        nowUptimeMs - lastScanUptimeMs >= throttleMs -> ScanThrottle.SCAN_NOW
        scanAlreadyPending -> ScanThrottle.ALREADY_PENDING
        else -> ScanThrottle.SCHEDULE_TRAILING
    }

    /// Delay del trailing scan: residuo del throttle (mai negativo) + margine.
    internal fun trailingScanDelayMs(
        nowUptimeMs: Long,
        lastScanUptimeMs: Long,
        throttleMs: Long,
        marginMs: Long,
    ): Long = (lastScanUptimeMs + throttleMs - nowUptimeMs).coerceAtLeast(0L) + marginMs

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

    /// Dismiss IMMEDIATO sullo stesso callback dell'evento recents: BACK
    /// chiude la schermata tornando al launcher sottostante senza relaunch
    /// dell'Activity — il flash si riduce alla latenza di consegna
    /// dell'evento (la recents rimbalza a metà animazione). Richiesta
    /// esplicita di design: dal launcher la funzione nativa va bloccata,
    /// non "aperta e richiusa". Niente verify differito: la provenienza è
    /// già stata verificata al decision time; il costo residuo è un raro
    /// falso kick da lag UsageStats (swipe entro ~1s dal lancio di un'app),
    /// accettato in cambio del blocco istantaneo. Anche il quick-switch dal
    /// launcher che passa dalla RecentsActivity viene bloccato — coerente:
    /// è un accesso alle app recenti.
    private fun performImmediateKick(
        service: KoruAccessibilityService,
        pkg: String,
        className: String,
    ) {
        if (pendingKick != null) return
        BlackBox.log(
            "RECENTS",
            "gesture recents dal launcher: $pkg/$className → dismiss immediato (BACK)",
        )
        // suppressLauncherNavigationUntilMs viene settato dall'helper: anche
        // il fallback BACK→HOME interno non resetta la sub-pagina launcher.
        service.performGoHomeForBlock(forceHome = false)
        // Fallback: se a +500ms la sessione è ancora aperta (nessun window
        // event di ritorno) il BACK non è bastato → forza HOME. `pendingKick`
        // fa anche da marker anti-doppio-BACK per le re-emissioni recents
        // durante la chiusura (vedi early-return in handleEvent).
        val fallback = Runnable {
            pendingKick = null
            // Igiene post-onDestroy (stesso guard degli altri delayed
            // runnable del service).
            if (KoruAccessibilityService.instance !== service) return@Runnable
            if (!recentsVisible) return@Runnable // dismiss riuscito
            // Foreground reale già un'app vera (≠ Koru, ≠ host recents
            // plausibile — STESSO predicato della detection, set diversi qui
            // rendevano il fallback cieco sugli OEM fuori da SKIP): l'utente
            // è uscito da solo, niente HOME.
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
                BlackBox.log("RECENTS", "fallback HOME annullato: foreground reale=$fg")
                endSession(service)
                return@Runnable
            }
            BlackBox.log("RECENTS", "BACK insufficiente → fallback HOME")
            service.performGoHomeForBlock(forceHome = true)
        }
        pendingKick = fallback
        mainHandler.postDelayed(fallback, KICK_FALLBACK_DELAY_MS)
    }

    private fun onNonRecentsWindow(service: KoruAccessibilityService, pkg: String) {
        pendingKick?.let {
            mainHandler.removeCallbacks(it)
            pendingKick = null
            BlackBox.log("RECENTS", "fallback HOME annullato: finestra reale $pkg")
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
        pendingInitialScan?.let {
            mainHandler.removeCallbacks(it)
            pendingInitialScan = null
        }
        cancelOneShotScan()
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
            // Diagnostica: id e testi di OGNI click in sessione (non solo i
            // match) — serve a pinnare l'id del bottone clear-all sugli OEM
            // non coperti (es. net.oneplus.launcher su OxygenOS 11) leggendo
            // la BlackBox dopo una prova on-device. Volume limitato: i click
            // arrivano solo a sessione recents attiva e da host plausibile.
            BlackBox.log(
                "RECENTS",
                "click in recents ($pkg): id=$viewId text=$text" +
                    " desc=${event.contentDescription}",
            )
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
        pendingInitialScan?.let { mainHandler.removeCallbacks(it) }
        pendingInitialScan = null
        pendingOneShotScan?.let { mainHandler.removeCallbacks(it) }
        pendingOneShotScan = null
        pendingOneShotScanDueUptimeMs = 0L
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
        pendingInitialScan = null
        pendingOneShotScan = null
        pendingOneShotScanDueUptimeMs = 0L
        clearAllRetryBudget = 0
        shieldActive = false
        allowUntilUptimeMs = 0L
        sessionAllowed = false
        recentsVisible = false
        lastRecentsScanUptimeMs = 0L
    }
}
