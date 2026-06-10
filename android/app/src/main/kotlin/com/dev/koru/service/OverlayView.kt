package com.dev.koru.service

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dev.koru.R
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig
import kotlinx.coroutines.delay

// -----------------------------------------------------------------------------
// Compose UI dell'overlay di blocco Koru.
//
// ARCH-05: estratto da OverlayManager.kt per separare il RENDERING (queste
// @Composable pure, che ricevono dati + callback) dalla GESTIONE DELLA FINESTRA
// (OverlayManager: WindowManager addView/removeView, isShowing, BypassStore
// delegation). Nessun cambio di logica: le funzioni sono state spostate
// verbatim. L'unico punto di contatto con OverlayManager e' [BlockedScreen],
// invocato dal suo `setContent`; resta `internal` (stesso package/module).
// Le costanti colore sono `internal` perche' OverlayManager.show() le usa anche
// per il `darkColorScheme` dell'overlay.
// -----------------------------------------------------------------------------

/// Palette Koru (mirror di lib/core/constants/koru_colors.dart)
internal val KoruBgBase = Color(0xFF0E100F)
internal val KoruSurface = Color(0xFF1A1D1B)
internal val KoruPrimary = Color(0xFF5C8262)
internal val KoruTextPrimary = Color(0xFFE8E6E1)
internal val KoruTextSecondary = Color(0xFF8B8F8A)

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
internal fun BlockedScreen(
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

            // Header: icona lineare per-reason tinta col verde Koru (mirror
            // delle icone outline dell'anteprima Flutter). Sostituisce le vecchie
            // emoji colorate per allinearsi al minimalismo dell'app.
            Icon(
                painter = painterResource(reasonIcon(reason)),
                contentDescription = null,
                tint = KoruPrimary,
                modifier = Modifier.size(64.dp),
            )
            Spacer(Modifier.height(28.dp))
            Text(
                text = reasonTitle(reason, config),
                color = KoruTextPrimary,
                fontSize = 26.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = (-0.2).sp,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(10.dp))
            Text(
                text = config.messageSubtitle ?: "paused by “$profileTitle”",
                color = KoruTextPrimary.copy(alpha = 0.70f),
                fontSize = 15.sp,
                letterSpacing = 0.1.sp,
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

            // CTA primaria sopra: "Don't open" è l'azione che vogliamo
            // incoraggiare, quindi sta in cima; il timer/countdown (escape hatch
            // gateato da frizione) vive sotto.
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
                Text(
                    "Don't open $appLabel",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 0.2.sp,
                )
            }
            Spacer(Modifier.height(16.dp))

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
                    onTapAfterFinish = { showDurationPicker = true },
                )

                if (bypassPolicy.countToday > 0) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = "Bypassed ${bypassPolicy.countToday}× today",
                        color = KoruTextPrimary.copy(alpha = 0.60f),
                        fontSize = 12.sp,
                        letterSpacing = 0.3.sp,
                    )
                }
            } else {
                LockedIndicator(reason = reason)
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

        Icon(
            painter = painterResource(R.drawable.ic_block_hourglass),
            contentDescription = null,
            tint = KoruPrimary,
            modifier = Modifier.size(64.dp),
        )
        Spacer(Modifier.height(28.dp))
        Text(
            text = "How long?",
            color = KoruTextPrimary,
            fontSize = 26.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = (-0.2).sp,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            text = if (bypassCountToday > 0) {
                "$appLabel — bypass #${bypassCountToday + 1} today. " +
                    "It will be blocked again after this time."
            } else {
                "$appLabel will be blocked again after this time."
            },
            color = KoruTextPrimary.copy(alpha = 0.70f),
            fontSize = 15.sp,
            letterSpacing = 0.1.sp,
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
                color = KoruTextPrimary.copy(alpha = 0.70f),
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
            fontSize = 17.sp,
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

        Icon(
            painter = painterResource(R.drawable.ic_block_alarm),
            contentDescription = null,
            tint = KoruPrimary,
            modifier = Modifier.size(64.dp),
        )
        Spacer(Modifier.height(28.dp))
        Text(
            text = "Time's up",
            color = KoruTextPrimary,
            fontSize = 26.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = (-0.2).sp,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            text = "How much longer with $appLabel?",
            color = KoruTextPrimary.copy(alpha = 0.70f),
            fontSize = 15.sp,
            letterSpacing = 0.1.sp,
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
            Text(
                "Close $appLabel",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                letterSpacing = 0.2.sp,
            )
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
            color = KoruTextPrimary.copy(alpha = 0.80f),
            fontSize = 14.sp,
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
            color = KoruTextPrimary.copy(alpha = 0.60f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun CountdownButton(
    durationMs: Int,
    finishedText: String,
    pauseAllowed: Boolean,
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
                fontSize = if (phase == CountdownPhase.FINISHED) 17.sp else 30.sp,
                fontWeight =
                    if (phase == CountdownPhase.FINISHED) FontWeight.Medium else FontWeight.SemiBold,
            )
        }
    }
}

/// Icona lineare per-reason (vector drawable in res/drawable). Mirror, dove
/// esistono, delle icone outline dell'anteprima Flutter (block_overlay_screen):
/// spa / self_improvement / layers_clear / language; hourglass e alarm coprono i
/// due reason solo-nativi (USAGE_LIMIT, BYPASS_EXPIRED).
private fun reasonIcon(reason: BlockReason): Int = when (reason) {
    BlockReason.FOCUS_MODE -> R.drawable.ic_block_self_improvement
    BlockReason.SECTION_BLOCKED -> R.drawable.ic_block_layers_clear
    BlockReason.WEBSITE_BLOCKED -> R.drawable.ic_block_language
    BlockReason.APP_BLOCKED -> R.drawable.ic_block_spa
    BlockReason.USAGE_LIMIT -> R.drawable.ic_block_hourglass
    BlockReason.BYPASS_EXPIRED -> R.drawable.ic_block_alarm
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
