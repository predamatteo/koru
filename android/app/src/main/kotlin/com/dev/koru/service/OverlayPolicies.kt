package com.dev.koru.service

import android.content.Context
import com.dev.koru.overlay.OverlayConfig

/**
 * Shared builder per la coppia (OverlayConfig, BypassPolicy) usata sui
 * blocchi USAGE_LIMIT. Esiste come top-level perché lo usano sia
 * [KoruAccessibilityService] (path primario, event-driven) sia
 * [LockForegroundService] tramite [LockRunnable] (backup polling) — la
 * logica deve essere identica nei due path, altrimenti il fallback
 * comportamentalmente diverge dal primario.
 */
object OverlayPolicies {

    /**
     * Strict ⇒ hard cap. Niente "Open anyway" (allowBypassAfterCountdown
     * forzato a `false` indipendentemente dall'overlay config configurata
     * dall'utente per quell'app/profilo).
     *
     * Non strict ⇒ progressive friction. Countdown 15→30→60→120s e durate
     * 5/10 min → 1/2 min dopo 3 bypass nel giorno corrente. Pause del
     * countdown disabilitato (era escape hatch gratuito).
     */
    fun buildUsageLimitOverlay(
        context: Context,
        pkg: String,
        isStrict: Boolean,
    ): Pair<OverlayConfig, BypassPolicy> {
        if (isStrict) {
            return OverlayConfig.DEFAULT.copy(
                allowBypassAfterCountdown = false,
            ) to BypassPolicy()
        }
        val count = BypassCountStore.todayCount(context, pkg)
        val countdown = when (count) {
            0 -> 15
            1 -> 30
            2 -> 60
            else -> 120
        }
        val durations = if (count >= 3) {
            listOf("1 min" to 1L * 60_000L, "2 min" to 2L * 60_000L)
        } else {
            listOf("5 min" to 5L * 60_000L, "10 min" to 10L * 60_000L)
        }
        return OverlayConfig.DEFAULT to BypassPolicy(
            countToday = count,
            durations = durations,
            countdownSecondsOverride = countdown,
            pauseAllowed = false,
        )
    }
}
