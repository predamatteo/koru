package com.dev.koru.service

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.WindowInsets
import android.view.WindowManager
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig

/**
 * Politica di bypass per un singolo invocazione di overlay. Calcolata dal
 * caller (KoruAccessibilityService) in base allo stato corrente
 * (BypassCountStore + strict flag in AppUsageLimitsStore).
 *
 * @property countToday n. di bypass usati oggi per il pkg corrente. Esposto
 *   nella UI come hint ("Bypassed N times today") per dare visibilità sulla
 *   pressione che si sta accumulando.
 * @property durations opzioni proposte all'utente nel duration picker
 *   (e nel BYPASS_EXPIRED prompt). Decrescenti con il count: 5/10 min per i
 *   primi bypass, 1/2 min dopo soglia.
 * @property countdownSecondsOverride se non null, sovrascrive il countdown
 *   standard di OverlayConfig (la frizione progressiva lo aumenta).
 * @property pauseAllowed se false, il CountdownButton non risponde al tap
 *   con "paused" — rimuove l'escape hatch del countdown infinito-pausabile.
 */
data class BypassPolicy(
    val countToday: Int = 0,
    val durations: List<Pair<String, Long>> = defaultBypassDurations,
    val countdownSecondsOverride: Int? = null,
    val pauseAllowed: Boolean = true,
)

/// Le opzioni standard, allineate ai pattern minimalist_phone / Opal /
/// ScreenZen. Override nella BypassPolicy quando serve frizione.
val defaultBypassDurations: List<Pair<String, Long>> = listOf(
    "1 min" to 1L * 60_000L,
    "5 min" to 5L * 60_000L,
    "15 min" to 15L * 60_000L,
    "30 min" to 30L * 60_000L,
)

/**
 * Stato di un bypass attivo: scadenza + il MOTIVO per cui è stato concesso.
 *
 * Il `reason` è la chiave per non far collassare restrizioni indipendenti.
 * Un'app può essere bloccata contemporaneamente da un profilo (schedule) e
 * da un cap giornaliero; il bypass però era una sola mappa `pkg → scadenza`
 * senza memoria del perché, quindi un "Open anyway" su un blocco di profilo
 * sopprimeva anche il daily limit (bug "+5 min all'infinito sul cap passando
 * dal blocco di profilo"). Memorizzando il reason possiamo far sì che solo
 * un bypass NATO DAL limite sospenda il limite — vedi
 * [OverlayManager.isLimitBypassActive].
 *
 * La scadenza è registrata su DUE orologi: [untilWall] (wall-clock) e
 * [untilElapsed] (clock monotonico [SystemClock.elapsedRealtime], che non
 * torna indietro). Vedi [isActive].
 */
data class BypassEntry(
    val untilWall: Long,
    val untilElapsed: Long,
    val reason: BlockReason,
) {
    /// Attivo solo se NÉ il wall-clock NÉ il clock monotonico sono scaduti.
    /// L'AND è anti-manipolazione: spostando l'orologio INDIETRO per estendere
    /// un bypass, `untilElapsed` (monotonico, non riavvolgibile senza root)
    /// scatta comunque a fine durata reale → niente estensione. Dopo un REBOOT
    /// `elapsedRealtime` riparte da 0, ma `untilWall` fa scadere il bypass alla
    /// sua ora naturale. Spostare l'orologio in avanti può solo anticipare la
    /// scadenza (non è un attacco).
    ///
    /// Caso limite reboot+clock-indietro insieme: isActive() può tornare true,
    /// ma NON c'è estensione utile — il reboot termina i processi di
    /// enforcement e toglie l'app dal foreground, e il cap giornaliero
    /// (wall-based, monotòno crescente, indipendente da isActive) resta
    /// esigibile. Al massimo si conserva la finestra wall originale, mai di
    /// più. Parametri iniettabili per i test.
    fun isActive(
        nowWall: Long = System.currentTimeMillis(),
        nowElapsed: Long = SystemClock.elapsedRealtime(),
    ): Boolean = nowElapsed < untilElapsed && nowWall < untilWall
}

/**
 * Window overlay con il BlockOverlay Koru, identico per feature all'overlay
 * Flutter `BlockOverlayScreen`:
 *  - header icon + title (varia per [BlockReason])
 *  - mindful intention prompt con ChoiceChip
 *  - countdown button con state machine animating ↔ paused → finished
 *  - "Don't open" primary button (sempre visibile)
 *  - "Open anyway" dopo countdown (solo se config.allowBypassAfterCountdown)
 */
class OverlayManager(private val context: Context) : LifecycleOwner, SavedStateRegistryOwner {

    companion object {
        private const val TAG = "OverlayManager"

        /// Context applicativo per la persistenza cross-process dei bypass
        /// (vedi [BypassStore]). Inizializzato dal costruttore di OverlayManager
        /// in ENTRAMBI i processi (`:accessibility` e main), così i metodi
        /// companion — chiamati SENZA Context da KoruAccessibilityService,
        /// LockRunnable, ecc. — possono raggiungere lo store condiviso su disco
        /// senza dover propagare un Context in ogni call site.
        /// @Volatile: scritto in onCreate/onServiceConnected, letto da altri thread.
        @Volatile
        private var appContext: Context? = null

        /// Da chiamare appena un OverlayManager esiste nel processo (idempotente).
        fun attachContext(context: Context) {
            appContext = context.applicationContext
        }

        /// Chiave del bypass. Per le APP e' il solo package (sblocca l'intera
        /// app). Per i SITI e' `package|dominio` cosi' "Open anyway" su
        /// reddit.com sblocca SOLO reddit.com e non l'intero browser: gli
        /// altri domini bloccati restano bloccati. Il `dominio` e' il name
        /// della regola che ha fatto match (vedi WebsiteMatcher.firstMatch),
        /// stabile rispetto alle varianti www/sottodominio della URL.
        private fun bypassKey(packageName: String, domain: String?): String =
            if (domain.isNullOrEmpty()) packageName else "$packageName|$domain"

        /// Stato persistito su [BypassStore] (file in filesDir), CONDIVISO tra i
        /// processi. Dopo "Open anyway" il bypass vale per la durata scelta
        /// MENTRE l'app è in foreground; all'uscita il caller
        /// (KoruAccessibilityService.onAccessibilityEvent o
        /// LockRunnable.checkAndBlock) lo revoca via [clearBypass]. Se
        /// [appContext] non è ancora agganciato, le query falliscono SAFE
        /// (nessun bypass → il blocco resta attivo).
        fun isBypassed(packageName: String, domain: String? = null): Boolean {
            val ctx = appContext ?: return false
            return BypassStore.read(ctx)[bypassKey(packageName, domain)]?.isActive() ?: false
        }

        /// Il motivo per cui [packageName] (eventualmente scoped a [domain]) è
        /// attualmente bypassato, o null se non c'è alcun bypass attivo.
        fun bypassReason(packageName: String, domain: String? = null): BlockReason? {
            val ctx = appContext ?: return null
            val entry = BypassStore.read(ctx)[bypassKey(packageName, domain)] ?: return null
            return if (entry.isActive()) entry.reason else null
        }

        /// True solo se è attivo un bypass NATO DAL daily limit (overlay
        /// USAGE_LIMIT di "entry" o estensione BYPASS_EXPIRED). Soltanto questo
        /// tipo di bypass deve sospendere il re-block del cap giornaliero per
        /// la durata scelta: è il flusso legittimo "+5/+10 min sul limite" con
        /// frizione progressiva. Un bypass di profilo/sezione (APP_BLOCKED,
        /// SECTION_BLOCKED, WEBSITE_BLOCKED) NON ricarica il budget del cap →
        /// ritorna false, così il limite resta esigibile anche dopo che
        /// l'utente ha forzato il blocco di profilo.
        fun isLimitBypassActive(packageName: String, domain: String? = null): Boolean =
            when (bypassReason(packageName, domain)) {
                BlockReason.USAGE_LIMIT, BlockReason.BYPASS_EXPIRED -> true
                else -> false
            }

        fun markBypassed(
            packageName: String,
            durationMs: Long,
            domain: String? = null,
            reason: BlockReason = BlockReason.APP_BLOCKED,
        ) {
            val ctx = appContext ?: return
            BypassStore.put(
                ctx,
                bypassKey(packageName, domain),
                BypassEntry(
                    untilWall = System.currentTimeMillis() + durationMs,
                    untilElapsed = SystemClock.elapsedRealtime() + durationMs,
                    reason = reason,
                ),
            )
        }

        /// Rimuove il bypass per questo pacchetto: sia quello per-app (chiave
        /// = package) sia TUTTI i per-dominio (chiavi `package|*`).
        /// Chiamato dall'auto-revoke quando l'utente esce dall'app/browser,
        /// quindi deve azzerare ogni variante per quel package.
        fun clearBypass(packageName: String) {
            val ctx = appContext ?: return
            BypassStore.removePackage(ctx, packageName)
        }

        /// Revoca tutti i bypass attivi. Caller:
        ///  - strict mode toggle: quando l'utente attiva strict, eventuali
        ///    bypass timed pendenti non hanno più senso e vanno azzerati;
        ///  - screen-off (KoruAccessibilityService.handleScreenOff e
        ///    LockRunnable sulla transizione interactive→off): il lock chiude
        ///    la sessione come l'uscita dall'app. "All" e non per-pkg perche'
        ///    il tracking del pkg bypassato puo' essere perso (service
        ///    restart) e per invariante al massimo un package ha bypass vivi.
        fun revokeAllBypasses() {
            val ctx = appContext ?: return
            BypassStore.clearAll(ctx)
        }
    }

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateRegistryController.savedStateRegistry

    private var windowManager: WindowManager? = null
    private var overlayView: ComposeView? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    @Volatile
    private var isShowing = false

    /// Compose-observable. Una `var String` veniva trattata come "stable
    /// param" dal compiler e non triggerava ricomposizioni quando il show()
    /// successivo cambiava pkg (es. utente passa da IG a YT senza che
    /// l'overlay venga rimosso). Ora ogni ricomposizione rilegge `.value`.
    private val _currentPackageName = mutableStateOf("")
    val currentPackageName: String get() = _currentPackageName.value
    private val _appLabel = mutableStateOf("")
    private val _profileTitle = mutableStateOf("")
    private val _reason = mutableStateOf(BlockReason.APP_BLOCKED)
    private val _config = mutableStateOf(OverlayConfig.DEFAULT)

    /// Callback quando l'utente tocca "Go back" → torna alla home.
    ///
    /// @param forceHome `true` quando il caller vuole una HOME "dura":
    /// usato dal flow BYPASS_EXPIRED, dove "Close $app" non è solo "torna
    /// indietro" ma una richiesta esplicita di rimuovere l'app dal foreground
    /// (l'utente è dentro la app, non sta provando ad aprirla). Il caller
    /// può lanciare ACTION_MAIN+CATEGORY_HOME in entrambi i casi, ma con
    /// `forceHome=true` può saltare logiche di "se sei già su home, no-op"
    /// e forzare anche `moveTaskToBack` o equivalenti.
    var onReturnHome: ((forceHome: Boolean) -> Unit)? = null

    /// Callback invocato quando l'utente sceglie una intention (per logging).
    var onIntentionChosen: ((pkg: String, intention: String) -> Unit)? = null

    /// Callback quando l'utente sceglie una durata dal duration picker
    /// (dopo aver toccato "Open anyway" sul countdown) → bypass timed + app launch.
    /// `domain` non-null solo per i blocchi website (scope per-dominio del bypass).
    var onBypassOpen: ((pkg: String, durationMs: Long, domain: String?) -> Unit)? = null

    init {
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        // Aggancia il context allo store dei bypass: da qui in poi i metodi
        // companion (isBypassed/markBypassed/...) raggiungono BypassStore in
        // questo processo. Lo fa OGNI OverlayManager → sia quello di
        // `:accessibility` sia quello del main puntano allo stesso filesDir.
        attachContext(context)
    }

    private var _profileEmoji = mutableStateOf<String?>(null)
    private var _bypassPolicy = mutableStateOf(BypassPolicy())

    /// Dominio bloccato quando reason == WEBSITE_BLOCKED (il name della regola
    /// che ha fatto match). Null per i blocchi app/sezione/focus. Usato come
    /// scope del bypass: "Open anyway" su un sito sblocca solo quel dominio
    /// (vedi markBypassed/onBypass). Resettato ad ogni show() → niente leak.
    private var _blockedDomain = mutableStateOf<String?>(null)

    fun show(
        packageName: String,
        appLabel: String,
        profileTitle: String,
        reason: BlockReason = BlockReason.APP_BLOCKED,
        config: OverlayConfig = OverlayConfig.DEFAULT,
        profileEmoji: String? = null,
        bypassPolicy: BypassPolicy = BypassPolicy(),
        blockedDomain: String? = null,
    ): Unit = synchronized(this) {
        // Se l'overlay è già visibile MA per un pacchetto diverso, forziamo
        // la dismiss + re-create. Questo previene il bug del countdown
        // "Open instagram" che restava mostrato anche dopo che l'utente
        // entrava in YouTube (i field venivano aggiornati, ma il `setContent`
        // non veniva re-eseguito perché currentPackageName era stable).
        if (isShowing && _currentPackageName.value != packageName) {
            Log.d(TAG, "show(): pkg changed ${_currentPackageName.value} → $packageName, recreating overlay")
            dismissInternal()
        }

        // Field update DOPO la guard: se sopra abbiamo fatto dismiss,
        // l'aggiornamento sotto popola la nuova istanza pulita. Se l'overlay
        // era già su con stesso pkg, aggiorna i field (es. reason cambia da
        // APP_BLOCKED → BYPASS_EXPIRED) e Compose ri-osserva via mutableState.
        _currentPackageName.value = packageName
        _appLabel.value = appLabel
        _profileTitle.value = profileTitle
        _reason.value = reason
        _config.value = config
        _profileEmoji.value = profileEmoji
        _bypassPolicy.value = bypassPolicy
        _blockedDomain.value = blockedDomain

        if (isShowing) return@synchronized

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                // Cutout: l'overlay deve coprire l'area del notch su display
                // con foro/tacca, altrimenti compare una banda nera che
                // rivela l'app sottostante per ~30px in alto.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                }
                // Stiamo già FLAG_LAYOUT_NO_LIMITS: la combinazione con
                // fitInsetsTypes=systemBars() su API 30+ ci dà copertura
                // sotto status/nav bar mantenendo il layout pulito.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    try {
                        fitInsetsTypes = WindowInsets.Type.systemBars()
                    } catch (_: Throwable) {
                        // Alcune ROM custom rompono questa API; skip silente.
                    }
                }
            }

            // Font scelto dall'utente (in-app), propagato al processo
            // :accessibility via UiSettingsStore. Risolto UNA volta per overlay
            // (I/O cache-ato in KoruFonts); null ⇒ font di sistema.
            val overlayFontFamily =
                KoruFonts.resolve(context, UiSettingsStore.activeFontId(context))

            val composeView = ComposeView(context).apply {
                setViewTreeLifecycleOwner(this@OverlayManager)
                setViewTreeSavedStateRegistryOwner(this@OverlayManager)
                setContent {
                    androidx.compose.material3.MaterialTheme(
                        colorScheme = darkColorScheme(
                            primary = KoruPrimary,
                            onPrimary = KoruTextPrimary,
                            surface = KoruSurface,
                            onSurface = KoruTextPrimary,
                            background = KoruBgBase,
                        ),
                    ) {
                        // Applica il fontFamily a TUTTI i Text dell'overlay via
                        // LocalTextStyle: i singoli Text fissano size/weight ma
                        // non la family, quindi la ereditano da qui. null = system.
                        androidx.compose.runtime.CompositionLocalProvider(
                            androidx.compose.material3.LocalTextStyle provides
                                androidx.compose.material3.LocalTextStyle.current.copy(
                                    fontFamily = overlayFontFamily,
                                ),
                        ) {
                        // I valori sono letti dai mutableState dentro la
                        // composable (vedi BlockedScreen): qui passiamo i
                        // .value per rendere esplicita la sottoscrizione.
                        BlockedScreen(
                            packageName = _currentPackageName.value,
                            appLabel = _appLabel.value,
                            profileTitle = _profileTitle.value,
                            reason = _reason.value,
                            config = _config.value,
                            profileEmoji = _profileEmoji.value,
                            bypassPolicy = _bypassPolicy.value,
                            onIntentionChosen = { intention ->
                                onIntentionChosen?.invoke(_currentPackageName.value, intention)
                            },
                            onGoHome = { forceHome -> onReturnHome?.invoke(forceHome) },
                            onBypass = { durationMs ->
                                // Salva il MOTIVO del blocco insieme al bypass: serve a
                                // [isLimitBypassActive] per non far sì che un bypass di
                                // profilo sospenda il cap giornaliero (e viceversa).
                                markBypassed(
                                    _currentPackageName.value,
                                    durationMs,
                                    _blockedDomain.value,
                                    _reason.value,
                                )
                                onBypassOpen?.invoke(_currentPackageName.value, durationMs, _blockedDomain.value)
                            },
                        )
                        }
                    }
                }
            }

            lifecycleRegistry.currentState = Lifecycle.State.RESUMED
            windowManager?.addView(composeView, params)
            overlayView = composeView
            overlayParams = params
            isShowing = true
            Log.d(TAG, "Overlay shown for $packageName (reason=$reason)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }

    fun dismiss(): Unit = synchronized(this) {
        dismissInternal()
    }

    /// Variante non-synchronized di dismiss(), per uso interno quando
    /// siamo già dentro un blocco synchronized(this) (es. show() che
    /// forza dismiss prima di re-create).
    private fun dismissInternal() {
        if (!isShowing) return
        // isShowing = false PRIMA del removeView: se una seconda chiamata
        // concorrente arriva mentre removeView è in corso, vede subito
        // !isShowing e ritorna, evitando doppio removeView (crash) e
        // doppio dismiss log.
        isShowing = false
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove overlay view", e)
        } finally {
            overlayView = null
            overlayParams = null
            try { lifecycleRegistry.currentState = Lifecycle.State.CREATED } catch (_: Exception) {}
            Log.d(TAG, "Overlay dismissed")
        }
    }

    fun isVisible(): Boolean = isShowing

    /// Reason dell'overlay attualmente mostrato (o l'ultimo se gia` dismissato).
    /// Usato dal caller per distinguere il flow "entry block" (abbiamo fatto HOME,
    /// app non in foreground) dal flow BYPASS_EXPIRED (app ancora in foreground).
    fun currentReason(): BlockReason = _reason.value

    /// Da invocare quando il Service host riceve `onConfigurationChanged`
    /// (rotazione, theme dark/light switch, locale change, density change).
    /// Senza questa propagazione l'overlay resta dimensionato per il
    /// vecchio config — su rotazione da portrait a landscape si vede una
    /// banda bianca sul lato corto del display.
    ///
    /// IMPORTANT: chiamare dal main thread (Service.onConfigurationChanged
    /// gira sul main thread di default, quindi nei call site standard
    /// non serve un Handler.post).
    fun onConfigurationChanged(): Unit = synchronized(this) {
        if (!isShowing) return@synchronized
        val view = overlayView ?: return@synchronized
        val params = overlayParams ?: return@synchronized
        try {
            windowManager?.updateViewLayout(view, params)
            Log.d(TAG, "Overlay relayout after configuration change")
        } catch (e: Exception) {
            Log.e(TAG, "updateViewLayout failed during config change", e)
        }
    }

    fun destroy() {
        dismiss()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
    }
}
