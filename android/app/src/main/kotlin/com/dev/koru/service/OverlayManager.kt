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

        /// Package name → timestamp ms fino a cui il blocco è bypassato
        /// (dopo click "Open anyway"). TTL 30s.
        private const val BYPASS_TTL_MS = 30_000L
        private val bypassedPackages = mutableMapOf<String, Long>()

        fun isBypassed(packageName: String): Boolean {
            val until = bypassedPackages[packageName] ?: return false
            return System.currentTimeMillis() < until
        }

        fun markBypassed(packageName: String) {
            bypassedPackages[packageName] = System.currentTimeMillis() + BYPASS_TTL_MS
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

    /// Callback quando l'utente tocca "Open anyway" → overlay bypass + app launch.
    var onBypassOpen: ((pkg: String) -> Unit)? = null

    init {
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
    }

    private var _profileEmoji = mutableStateOf<String?>(null)

    fun show(
        packageName: String,
        appLabel: String,
        profileTitle: String,
        reason: BlockReason = BlockReason.APP_BLOCKED,
        config: OverlayConfig = OverlayConfig.DEFAULT,
        profileEmoji: String? = null,
    ) {
        currentPackageName = packageName
        _appLabel.value = appLabel
        _profileTitle.value = profileTitle
        _reason.value = reason
        _config.value = config
        _profileEmoji.value = profileEmoji

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
                            onIntentionChosen = { intention ->
                                onIntentionChosen?.invoke(currentPackageName, intention)
                            },
                            onGoHome = { onReturnHome?.invoke() },
                            onBypass = {
                                markBypassed(currentPackageName)
                                onBypassOpen?.invoke(currentPackageName)
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
    onIntentionChosen: (String) -> Unit,
    onGoHome: () -> Unit,
    onBypass: () -> Unit,
) {
    val gradientTop = Color(config.backgroundColorArgb).copy(alpha = 0.95f)
    val gradient = Brush.verticalGradient(listOf(gradientTop, KoruBgBase))

    var countdownFinished by remember { mutableStateOf(false) }
    var chosenIntention by remember { mutableStateOf<String?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(gradient),
        contentAlignment = Alignment.Center,
    ) {
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

            CountdownButton(
                durationMs = config.countdownSeconds * 1000,
                finishedText = "Open $appLabel",
                onFinished = { countdownFinished = true },
                onTapAfterFinish = {
                    if (config.allowBypassAfterCountdown) onBypass()
                },
            )
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
                TextButton(onClick = onBypass) {
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

@Composable
private fun CountdownButton(
    durationMs: Int,
    finishedText: String,
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
                    "animating" -> phase = "paused"
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
}

private fun reasonTitle(reason: BlockReason, config: OverlayConfig): String =
    config.messageTitle ?: when (reason) {
        BlockReason.FOCUS_MODE -> "Focus mode is active"
        BlockReason.SECTION_BLOCKED -> "Section paused"
        BlockReason.WEBSITE_BLOCKED -> "Website paused"
        BlockReason.APP_BLOCKED -> "Take a breath"
        BlockReason.USAGE_LIMIT -> "Daily limit reached"
    }
