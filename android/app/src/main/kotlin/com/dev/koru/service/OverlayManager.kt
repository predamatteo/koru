package com.dev.koru.service

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
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
        /// il bypass resta valido per quella durata indipendentemente dal
        /// fatto che l'utente esca e rientri nell'app. Scaduta la durata,
        /// al prossimo ingresso il blocco si riattiva.
        private val bypassedPackages = mutableMapOf<String, Long>()

        fun isBypassed(packageName: String): Boolean {
            val until = bypassedPackages[packageName] ?: return false
            return System.currentTimeMillis() < until
        }

        fun markBypassed(packageName: String, durationMs: Long) {
            bypassedPackages[packageName] = System.currentTimeMillis() + durationMs
        }

        /// Rimuove immediatamente il bypass per questo pacchetto.
        /// Usato per debug / reset manuale — il flusso normale fa
        /// affidamento sulla scadenza naturale via TTL.
        fun clearBypass(packageName: String) {
            bypassedPackages.remove(packageName)
        }
    }

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateRegistryController.savedStateRegistry

    private var windowManager: WindowManager? = null
    private var overlayView: ComposeView? = null
    private var isShowing = false

    var currentPackageName: String = ""
        private set
    private var _appLabel = mutableStateOf("")
    private var _profileTitle = mutableStateOf("")
    private var _reason = mutableStateOf(BlockReason.APP_BLOCKED)
    private var _config = mutableStateOf(OverlayConfig.DEFAULT)

    /// Callback quando l'utente tocca "Go back" → torna alla home.
    var onReturnHome: (() -> Unit)? = null

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
    ) {
        currentPackageName = packageName
        _appLabel.value = appLabel
        _profileTitle.value = profileTitle
        _reason.value = reason
        _config.value = config
        _profileEmoji.value = profileEmoji
        _bypassPolicy.value = bypassPolicy

        if (isShowing) return

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.TOP or Gravity.START }

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
                        BlockedScreen(
                            packageName = currentPackageName,
                            appLabel = _appLabel.value,
                            profileTitle = _profileTitle.value,
                            reason = _reason.value,
                            config = _config.value,
                            profileEmoji = _profileEmoji.value,
                            bypassPolicy = _bypassPolicy.value,
                            onIntentionChosen = { intention ->
                                onIntentionChosen?.invoke(currentPackageName, intention)
                            },
                            onGoHome = { onReturnHome?.invoke() },
                            onBypass = { durationMs ->
                                markBypassed(currentPackageName, durationMs)
                                onBypassOpen?.invoke(currentPackageName, durationMs)
                            },
                        )
                    }
                }
            }

            lifecycleRegistry.currentState = Lifecycle.State.RESUMED
            windowManager?.addView(composeView, params)
            overlayView = composeView
            isShowing = true
            Log.d(TAG, "Overlay shown for $packageName (reason=$reason)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }

    fun dismiss() {
        if (!isShowing) return
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove overlay view", e)
        } finally {
            overlayView = null
            isShowing = false
            try { lifecycleRegistry.currentState = Lifecycle.State.CREATED } catch (_: Exception) {}
            Log.d(TAG, "Overlay dismissed")
        }
    }

    fun isVisible(): Boolean = isShowing

    /// Reason dell'overlay attualmente mostrato (o l'ultimo se gia` dismissato).
    /// Usato dal caller per distinguere il flow "entry block" (abbiamo fatto HOME,
    /// app non in foreground) dal flow BYPASS_EXPIRED (app ancora in foreground).
    fun currentReason(): BlockReason = _reason.value

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
    onGoHome: () -> Unit,
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
                onCloseApp = onGoHome,
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
                onClick = onGoHome,
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
    var phase by remember { mutableStateOf("animating") }
    var elapsedMs by remember { mutableStateOf(0L) }
    val progress = (elapsedMs.toFloat() / durationMs).coerceIn(0f, 1f)
    val totalSec = durationMs / 1000
    val remainingSec = ((1f - progress) * totalSec).toInt().coerceAtLeast(0) +
        if (progress < 1f) 1 else 0

    // Tick every 50ms while animating.
    LaunchedEffect(phase) {
        if (phase != "animating") return@LaunchedEffect
        while (phase == "animating" && elapsedMs < durationMs) {
            delay(50L)
            elapsedMs += 50L
        }
        if (elapsedMs >= durationMs && phase == "animating") {
            phase = "finished"
            onFinished()
        }
    }

    val display = when (phase) {
        "finished" -> finishedText
        "paused" -> "Paused"
        else -> remainingSec.toString()
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
                    "animating" -> if (pauseAllowed) phase = "paused"
                    "paused" -> phase = "animating"
                    "finished" -> onTapAfterFinish()
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
                fontSize = if (phase == "finished") 18.sp else 28.sp,
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
