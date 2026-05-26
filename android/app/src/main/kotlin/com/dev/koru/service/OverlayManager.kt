package com.dev.koru.service

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.WindowInsets
import android.view.WindowManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import kotlinx.coroutines.delay

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
 */
data class BypassEntry(val until: Long, val reason: BlockReason)

/// Palette Koru (mirror di lib/core/constants/koru_colors.dart)
private val KoruBgBase = Color(0xFF0E100F)
private val KoruSurface = Color(0xFF1A1D1B)
private val KoruPrimary = Color(0xFF5C8262)
private val KoruTextPrimary = Color(0xFFE8E6E1)
private val KoruTextSecondary = Color(0xFF8B8F8A)

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
            val entry = BypassStore.read(ctx)[bypassKey(packageName, domain)] ?: return false
            return System.currentTimeMillis() < entry.until
        }

        /// Il motivo per cui [packageName] (eventualmente scoped a [domain]) è
        /// attualmente bypassato, o null se non c'è alcun bypass attivo.
        fun bypassReason(packageName: String, domain: String? = null): BlockReason? {
            val ctx = appContext ?: return null
            val entry = BypassStore.read(ctx)[bypassKey(packageName, domain)] ?: return null
            return if (System.currentTimeMillis() < entry.until) entry.reason else null
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
                BypassEntry(System.currentTimeMillis() + durationMs, reason),
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

        /// Revoca tutti i bypass attivi. Esposto per strict mode toggle:
        /// quando l'utente attiva strict, eventuali bypass timed pendenti
        /// non hanno più senso e vanno azzerati.
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

// -----------------------------------------------------------------------------
// Compose UI
// -----------------------------------------------------------------------------

private val mindfulIntentions = listOf(
    "Reply to a message",
    "Check one thing",
    "Just scroll",
    "Not sure",
)

/// State machine del CountdownButton. Sostituisce le magic string
/// "animating" / "paused" / "finished" usate in precedenza — i refactor
/// silenziosi di una stringa erano un magnete per bug.
private enum class CountdownPhase { ANIMATING, PAUSED, FINISHED }

@Composable
private fun BlockedScreen(
    packageName: String,
    appLabel: String,
    profileTitle: String,
    reason: BlockReason,
    config: OverlayConfig,
    profileEmoji: String?,
    bypassPolicy: BypassPolicy,
    onIntentionChosen: (String) -> Unit,
    onGoHome: (forceHome: Boolean) -> Unit,
    onBypass: (durationMs: Long) -> Unit,
) {
    // Overlay completamente opaco (niente bleed-through dall'app bloccata
     // sottostante) + gradiente sottile dal colore palette al base dark.
    val gradientTop = Color(config.backgroundColorArgb)
    val gradient = Brush.verticalGradient(listOf(gradientTop, KoruBgBase))

    var countdownFinished by remember { mutableStateOf(false) }
    var chosenIntention by remember { mutableStateOf<String?>(null) }
    // Step "duration picker": quando true, sostituisce il contenuto
    // principale con il picker di durata per il bypass.
    var showDurationPicker by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(gradient),
        contentAlignment = Alignment.Center,
    ) {
        // Bypass TTL scaduto mentre utente era dentro l'app → non il
        // blocco "entry" classico ma un prompt di estensione (stile
        // minimalist_phone): "Time's up, vuoi altri N min o chiudi?"
        if (reason == BlockReason.BYPASS_EXPIRED) {
            ExtensionPromptSection(
                appLabel = appLabel,
                durations = bypassPolicy.durations,
                onDurationChosen = { durationMs -> onBypass(durationMs) },
                // forceHome=true: l'utente è DENTRO l'app (TTL scaduto
                // mentre era in foreground), non sta solo provando ad
                // entrare. "Close $app" implica buttare via la task,
                // non un semplice navigate-to-launcher.
                onCloseApp = { onGoHome(true) },
            )
            return@Box
        }

        if (showDurationPicker) {
            DurationPickerSection(
                appLabel = appLabel,
                config = config,
                durations = bypassPolicy.durations,
                bypassCountToday = bypassPolicy.countToday,
                onDurationChosen = { durationMs ->
                    showDurationPicker = false
                    onBypass(durationMs)
                },
                onCancel = { showDurationPicker = false },
            )
            return@Box
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 32.dp, vertical = 48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            // Preferisci l'emoji del profilo (scelta dall'utente); fallback
            // all'emoji della reason se il profilo non ha un'icona custom.
            val headerEmoji = when {
                !profileEmoji.isNullOrBlank() && profileEmoji != "NoIcon" -> profileEmoji
                else -> reasonEmoji(reason)
            }
            Text(
                text = headerEmoji,
                fontSize = 56.sp,
            )
            Spacer(Modifier.height(24.dp))
            Text(
                text = reasonTitle(reason, config),
                color = KoruTextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = config.messageSubtitle ?: "paused by \u201C$profileTitle\u201D",
                color = KoruTextPrimary.copy(alpha = 0.78f),
                fontSize = 16.sp,
                textAlign = TextAlign.Center,
            )

            if (reason == BlockReason.APP_BLOCKED || reason == BlockReason.SECTION_BLOCKED) {
                Spacer(Modifier.height(32.dp))
                MindfulIntentionPrompt(
                    selected = chosenIntention,
                    onSelected = {
                        chosenIntention = it
                        onIntentionChosen(it)
                    },
                )
            }

            Spacer(Modifier.weight(1f))

            // Frizione progressiva: il countdown standard di OverlayConfig
            // (8s) è troppo basso quando l'utente sta provando a sforare un
            // limite per la 4ª volta — la BypassPolicy del USAGE_LIMIT non
            // strict lo allunga (15→30→60→120s).
            val effectiveCountdownSec =
                bypassPolicy.countdownSecondsOverride ?: config.countdownSeconds

            // In strict mode (allowBypassAfterCountdown=false) NON renderiamo
            // il CountdownButton: il suo unico scopo è gateare il bypass con
            // frizione, ma senza bypass è solo un pulsante "Open $appLabel"
            // che non fa niente al tap (bug osservato: utente aspetta 8s
            // di countdown su strict, tappa "Open instagram", nulla succede).
            // Mostriamo invece un lock indicator non-actionable per dare
            // feedback visivo dello stato bloccato; l'unica CTA è "Don't open".
            if (config.allowBypassAfterCountdown) {
                // Il pause-toggle è un escape hatch: clicchi sul countdown → si
                // ferma il timer → infinitamente. Per i blocchi "duri" (USAGE_LIMIT,
                // BYPASS_EXPIRED) lo disabilitiamo, lasciandolo solo nei flow
                // mindful (APP_BLOCKED entry) dove la pausa fa parte dell'UX.
                CountdownButton(
                    durationMs = effectiveCountdownSec * 1000,
                    finishedText = "Open $appLabel",
                    pauseAllowed = bypassPolicy.pauseAllowed,
                    onFinished = { countdownFinished = true },
                    onTapAfterFinish = { showDurationPicker = true },
                )

                if (bypassPolicy.countToday > 0) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = "Bypassed ${bypassPolicy.countToday}× today",
                        color = KoruTextPrimary.copy(alpha = 0.55f),
                        fontSize = 12.sp,
                    )
                }
            } else {
                LockedIndicator(reason = reason)
            }
            Spacer(Modifier.height(16.dp))

            Button(
                onClick = { onGoHome(false) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = KoruTextPrimary,
                    contentColor = Color(config.backgroundColorArgb),
                ),
            ) {
                Text("Don't open $appLabel", fontSize = 16.sp, fontWeight = FontWeight.Medium)
            }

            AnimatedVisibility(
                visible = countdownFinished && config.allowBypassAfterCountdown,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                TextButton(onClick = { showDurationPicker = true }) {
                    Text(
                        "Open anyway",
                        color = KoruTextPrimary.copy(alpha = 0.78f),
                        fontSize = 14.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun DurationPickerSection(
    appLabel: String,
    config: OverlayConfig,
    durations: List<Pair<String, Long>>,
    bypassCountToday: Int,
    onDurationChosen: (Long) -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        Text(
            text = "\u23F1\uFE0F", // ⏱️
            fontSize = 56.sp,
        )
        Spacer(Modifier.height(24.dp))
        Text(
            text = "How long?",
            color = KoruTextPrimary,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = if (bypassCountToday > 0) {
                "$appLabel — bypass #${bypassCountToday + 1} today. " +
                    "It will be blocked again after this time."
            } else {
                "$appLabel will be blocked again after this time."
            },
            color = KoruTextPrimary.copy(alpha = 0.78f),
            fontSize = 16.sp,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(40.dp))

        durations.forEach { (label, durationMs) ->
            DurationOptionButton(
                label = label,
                onClick = { onDurationChosen(durationMs) },
            )
            Spacer(Modifier.height(12.dp))
        }

        Spacer(Modifier.weight(1f))

        TextButton(onClick = onCancel) {
            Text(
                "Cancel",
                color = KoruTextPrimary.copy(alpha = 0.78f),
                fontSize = 14.sp,
            )
        }
    }
}

@Composable
private fun DurationOptionButton(
    label: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(KoruTextPrimary.copy(alpha = 0.10f))
            .clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            color = KoruTextPrimary,
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

/// Prompt mostrato quando scade il TTL di un bypass e l'utente e'
/// ancora dentro l'app (BlockReason.BYPASS_EXPIRED). Copia dal pattern
/// minimalist_phone: estensione granulare + "Close" esplicito.
@Composable
private fun ExtensionPromptSection(
    appLabel: String,
    durations: List<Pair<String, Long>>,
    onDurationChosen: (Long) -> Unit,
    onCloseApp: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        Text(
            text = "\u23F0", // ⏰
            fontSize = 56.sp,
        )
        Spacer(Modifier.height(24.dp))
        Text(
            text = "Time's up",
            color = KoruTextPrimary,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "How much longer with $appLabel?",
            color = KoruTextPrimary.copy(alpha = 0.78f),
            fontSize = 16.sp,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(40.dp))

        durations.forEach { (label, durationMs) ->
            DurationOptionButton(
                label = "+$label",
                onClick = { onDurationChosen(durationMs) },
            )
            Spacer(Modifier.height(12.dp))
        }

        Spacer(Modifier.weight(1f))

        Button(
            onClick = onCloseApp,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = KoruTextPrimary,
                contentColor = KoruBgBase,
            ),
        ) {
            Text("Close $appLabel", fontSize = 16.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun MindfulIntentionPrompt(
    selected: String?,
    onSelected: (String) -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "Why are you opening it?",
            color = KoruTextPrimary.copy(alpha = 0.85f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
        )
        Spacer(Modifier.height(12.dp))
        // Manual wrap su 2 righe (2 + 2) per evitare dipendenza da FlowRow
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            mindfulIntentions.take(2).forEach { intention ->
                IntentionChip(intention, selected == intention) { onSelected(intention) }
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            mindfulIntentions.drop(2).forEach { intention ->
                IntentionChip(intention, selected == intention) { onSelected(intention) }
            }
        }
    }
}

@Composable
private fun IntentionChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label, fontSize = 13.sp) },
        colors = FilterChipDefaults.filterChipColors(
            containerColor = KoruSurface.copy(alpha = 0.6f),
            selectedContainerColor = KoruPrimary.copy(alpha = 0.35f),
            labelColor = KoruTextPrimary.copy(alpha = 0.85f),
            selectedLabelColor = KoruTextPrimary,
        ),
    )
}

/// Indicatore non-actionable mostrato al posto del CountdownButton quando
/// `allowBypassAfterCountdown == false` (strict mode). Comunica lo stato
/// bloccato senza promettere un'azione che il sistema non permette.
@Composable
private fun LockedIndicator(reason: BlockReason) {
    val text = when (reason) {
        BlockReason.USAGE_LIMIT -> "🔒  Locked until tomorrow"
        else -> "🔒  Locked"
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(KoruTextPrimary.copy(alpha = 0.06f)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            color = KoruTextPrimary.copy(alpha = 0.55f),
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun CountdownButton(
    durationMs: Int,
    finishedText: String,
    pauseAllowed: Boolean,
    onFinished: () -> Unit,
    onTapAfterFinish: () -> Unit,
) {
    // State machine: ANIMATING ↔ PAUSED → FINISHED.
    var phase by remember { mutableStateOf(CountdownPhase.ANIMATING) }
    var elapsedMs by remember { mutableStateOf(0L) }
    val progress = (elapsedMs.toFloat() / durationMs).coerceIn(0f, 1f)
    val totalSec = durationMs / 1000
    val remainingSec = ((1f - progress) * totalSec).toInt().coerceAtLeast(0) +
        if (progress < 1f) 1 else 0

    // Tick every 250ms while animating. Prima era 50ms (20Hz): ricomposizione
    // 20×/sec di un Box+Text non fa praticamente differenza visiva e brucia
    // CPU/battery quando l'overlay resta sul cellulare anche pochi secondi.
    // 250ms (4Hz) è sufficiente per il rendering smooth del countdown
    // numerico (1 secondo cambia di solo 0.25 unità) e taglia 5x il lavoro.
    LaunchedEffect(phase) {
        if (phase != CountdownPhase.ANIMATING) return@LaunchedEffect
        while (phase == CountdownPhase.ANIMATING && elapsedMs < durationMs) {
            delay(250L)
            elapsedMs += 250L
        }
        if (elapsedMs >= durationMs && phase == CountdownPhase.ANIMATING) {
            phase = CountdownPhase.FINISHED
            onFinished()
        }
    }

    val display = when (phase) {
        CountdownPhase.FINISHED -> finishedText
        CountdownPhase.PAUSED -> "Paused"
        CountdownPhase.ANIMATING -> remainingSec.toString()
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(KoruTextPrimary.copy(alpha = 0.10f))
            .clickable {
                when (phase) {
                    // Pausa disabilitata sui blocchi "duri": rimuove l'escape
                    // hatch del countdown infinito-pausabile (l'utente
                    // toccava il countdown per fermarlo, sceglieva di
                    // calmarsi e poi ripartiva — soft-bypass gratuito).
                    CountdownPhase.ANIMATING -> if (pauseAllowed) phase = CountdownPhase.PAUSED
                    CountdownPhase.PAUSED -> phase = CountdownPhase.ANIMATING
                    CountdownPhase.FINISHED -> onTapAfterFinish()
                }
            },
    ) {
        // Fill bar (from left)
        Box(
            modifier = Modifier
                .fillMaxWidth(progress)
                .height(64.dp)
                .background(KoruTextPrimary.copy(alpha = 0.30f)),
        )
        // Centered text
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                display,
                color = KoruTextPrimary,
                fontSize = if (phase == CountdownPhase.FINISHED) 18.sp else 28.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

private fun reasonEmoji(reason: BlockReason): String = when (reason) {
    BlockReason.FOCUS_MODE -> "\uD83E\uDDD8"       // 🧘
    BlockReason.SECTION_BLOCKED -> "\uD83D\uDED1"  // 🛑
    BlockReason.WEBSITE_BLOCKED -> "\uD83C\uDF10"  // 🌐
    BlockReason.APP_BLOCKED -> "\uD83C\uDF3F"      // 🌿
    BlockReason.USAGE_LIMIT -> "\u23F3"            // ⏳
    BlockReason.BYPASS_EXPIRED -> "\u23F0"          // ⏰
}

private fun reasonTitle(reason: BlockReason, config: OverlayConfig): String =
    config.messageTitle ?: when (reason) {
        BlockReason.FOCUS_MODE -> "Focus mode is active"
        BlockReason.SECTION_BLOCKED -> "Section paused"
        BlockReason.WEBSITE_BLOCKED -> "Website paused"
        BlockReason.APP_BLOCKED -> "Take a breath"
        BlockReason.USAGE_LIMIT -> "Daily limit reached"
        BlockReason.BYPASS_EXPIRED -> "Time's up"
    }
