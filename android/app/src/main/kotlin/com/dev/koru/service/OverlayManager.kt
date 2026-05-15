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
import java.util.concurrent.ConcurrentHashMap

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

        /// Package name → timestamp ms fino a cui il blocco è bypassato.
        /// Dopo che l'utente tocca "Open anyway" sull'overlay, sceglie
        /// esplicitamente una durata (1/5/15/30 min) dal duration picker;
        /// il bypass resta valido per quella durata MENTRE l'app è in
        /// foreground. Non appena l'utente esce dall'app (verso un'altra
        /// app o verso il launcher), il bypass viene revocato dal caller
        /// — KoruAccessibilityService.onAccessibilityEvent (path primario)
        /// o LockRunnable.checkAndBlock (backup polling) — via
        /// [clearBypass]. Al prossimo rientro nell'app, l'overlay con
        /// countdown ricompare: ogni sessione richiede una scelta esplicita,
        /// allineato al pattern Opal/ScreenZen.
        ///
        /// ConcurrentHashMap perché letto/scritto da thread misti:
        /// AccessibilityService (binder), LockRunnable (polling thread),
        /// main thread (UI callback onBypassOpen). MutableMap non sync
        /// causava ConcurrentModificationException sporadiche.
        private val bypassedPackages = ConcurrentHashMap<String, Long>()

        /// Cleanup interno: rimuove entries scadute. Chiamato pigramente
        /// da isBypassed / markBypassed per evitare leak senza un timer
        /// dedicato. La mappa resta piccola (1 entry per app bloccata)
        /// ma "best effort" garbage collection ci sta.
        private fun pruneExpired() {
            val now = System.currentTimeMillis()
            val iterator = bypassedPackages.entries.iterator()
            while (iterator.hasNext()) {
                val entry = iterator.next()
                if (entry.value < now) iterator.remove()
            }
        }

        fun isBypassed(packageName: String): Boolean {
            pruneExpired()
            val until = bypassedPackages[packageName] ?: return false
            return System.currentTimeMillis() < until
        }

        fun markBypassed(packageName: String, durationMs: Long) {
            pruneExpired()
            bypassedPackages[packageName] = System.currentTimeMillis() + durationMs
        }

        /// Rimuove immediatamente il bypass per questo pacchetto.
        /// Usato per debug / reset manuale — il flusso normale fa
        /// affidamento sulla scadenza naturale via TTL.
        fun clearBypass(packageName: String) {
            bypassedPackages.remove(packageName)
        }

        /// Revoca tutti i bypass attivi. Esposto per strict mode toggle:
        /// quando l'utente attiva strict, eventuali bypass timed pendenti
        /// non hanno più senso e vanno azzerati.
        fun revokeAllBypasses() {
            bypassedPackages.clear()
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
    var onBypassOpen: ((pkg: String, durationMs: Long) -> Unit)? = null

    init {
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
    }

    private var _profileEmoji = mutableStateOf<String?>(null)
    private var _bypassPolicy = mutableStateOf(BypassPolicy())

    fun show(
        packageName: String,
        appLabel: String,
        profileTitle: String,
        reason: BlockReason = BlockReason.APP_BLOCKED,
        config: OverlayConfig = OverlayConfig.DEFAULT,
        profileEmoji: String? = null,
        bypassPolicy: BypassPolicy = BypassPolicy(),
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
                                markBypassed(_currentPackageName.value, durationMs)
                                onBypassOpen?.invoke(_currentPackageName.value, durationMs)
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
