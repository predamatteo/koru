package com.dev.koru.service

import com.dev.koru.service.LauncherRecentsGate.Decision
import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test

/**
 * Test PURI della matrice di decisione del gate ([LauncherRecentsGate.decide]).
 * Copre la matrice degli stati verificata in fase di design:
 *
 * | Stato                                            | Esito atteso |
 * |--------------------------------------------------|--------------|
 * | A. Launcher visibile, swipe-up-hold              | BLOCK        |
 * | B. Altra app in fg, route Dart stale /launcher   | allow (prevFg corregge) |
 * | C. Dashboard Koru aperta (shield off)            | allow        |
 * | E. Recents aperta da dentro un'altra app         | allow        |
 * | Tap icona (token) / dentro sessione               | allow        |
 *
 * Le parti runtime (Handler, UsageStats, serviceInfo) sono integrazione,
 * verificate on-device coi log BlackBox tag RECENTS.
 */
class LauncherRecentsGateTest {

    @Before
    fun reset() {
        LauncherRecentsGate.debugResetState()
    }

    private fun decide(
        tokenValid: Boolean = false,
        sessionAllowed: Boolean = false,
        shieldActive: Boolean = false,
        cameFromKoru: Boolean = false,
    ) = LauncherRecentsGate.decide(tokenValid, sessionAllowed, shieldActive, cameFromKoru)

    @Test
    fun stateA_gestureOnLauncher_blocks() {
        assertThat(decide(shieldActive = true, cameFromKoru = true))
            .isEqualTo(Decision.BLOCK)
    }

    @Test
    fun stateB_otherAppForeground_staleShieldFlag_allows() {
        // RouteAware non vede il lancio di un'altra app: shield resta true ma
        // il guard di provenienza (cameFromKoru=false) corregge.
        assertThat(decide(shieldActive = true, cameFromKoru = false))
            .isEqualTo(Decision.ALLOW_NOT_FROM_KORU)
    }

    @Test
    fun stateC_dashboardOpen_shieldOff_allows() {
        // Il tasto K pusha /home sopra il launcher → didPushNext spegne lo
        // shield. cameFromKoru sarebbe true: è lo shield a portare la
        // correttezza qui (entrambi i termini sono necessari).
        assertThat(decide(shieldActive = false, cameFromKoru = true))
            .isEqualTo(Decision.ALLOW_SHIELD_OFF)
    }

    @Test
    fun iconTap_tokenWinsOverEverything() {
        assertThat(
            decide(tokenValid = true, shieldActive = true, cameFromKoru = true),
        ).isEqualTo(Decision.ALLOW_TOKEN)
    }

    @Test
    fun insideAllowedSession_noSpuriousKick() {
        // Utente fermo nelle recents oltre la scadenza del token: la sessione
        // sticky assorbe le re-emissioni recents → mai kick a metà sessione.
        assertThat(
            decide(sessionAllowed = true, shieldActive = true, cameFromKoru = true),
        ).isEqualTo(Decision.ALLOW_IN_SESSION)
    }

    @Test
    fun tokenHasPriorityOverSession() {
        // Doppia apertura via icona mentre una sessione era già attiva: il
        // token viene comunque consumato (ALLOW_TOKEN) e ri-arma la sessione.
        assertThat(
            decide(tokenValid = true, sessionAllowed = true, shieldActive = true),
        ).isEqualTo(Decision.ALLOW_TOKEN)
    }

    @Test
    fun everythingOff_allowsViaShieldOff() {
        assertThat(decide()).isEqualTo(Decision.ALLOW_SHIELD_OFF)
    }

    // ─── decideScanThrottle / trailingScanDelayMs (throttle trailing-edge) ──

    private val THROTTLE = 300L

    @Test
    fun scanThrottle_outsideWindow_scansNow() {
        assertThat(
            LauncherRecentsGate.decideScanThrottle(
                nowUptimeMs = 1_000L, lastScanUptimeMs = 700L,
                throttleMs = THROTTLE, scanAlreadyPending = false,
            ),
        ).isEqualTo(LauncherRecentsGate.ScanThrottle.SCAN_NOW)
    }

    @Test
    fun scanThrottle_insideWindow_schedulesTrailing() {
        // Il caso che il leading-edge puro perdeva: l'ultimo content-changed
        // della raffica (overview svuotata) cadeva nel throttle e veniva
        // scartato — lo zero non veniva mai letto.
        assertThat(
            LauncherRecentsGate.decideScanThrottle(
                nowUptimeMs = 1_000L, lastScanUptimeMs = 900L,
                throttleMs = THROTTLE, scanAlreadyPending = false,
            ),
        ).isEqualTo(LauncherRecentsGate.ScanThrottle.SCHEDULE_TRAILING)
    }

    @Test
    fun scanThrottle_insideWindowWithPendingScan_coalesces() {
        assertThat(
            LauncherRecentsGate.decideScanThrottle(
                nowUptimeMs = 1_000L, lastScanUptimeMs = 900L,
                throttleMs = THROTTLE, scanAlreadyPending = true,
            ),
        ).isEqualTo(LauncherRecentsGate.ScanThrottle.ALREADY_PENDING)
    }

    @Test
    fun scanThrottle_outsideWindowEvenWithPendingScan_scansNow() {
        // Il pending non sopprime lo scan fuori finestra: è il wrapper a
        // cancellare l'one-shot ridondante dopo lo scan immediato.
        assertThat(
            LauncherRecentsGate.decideScanThrottle(
                nowUptimeMs = 2_000L, lastScanUptimeMs = 700L,
                throttleMs = THROTTLE, scanAlreadyPending = true,
            ),
        ).isEqualTo(LauncherRecentsGate.ScanThrottle.SCAN_NOW)
    }

    @Test
    fun trailingDelay_isResidualPlusMargin() {
        // Ultimo scan a 900, ora 1000, throttle 300 → residuo 200 + 50.
        assertThat(
            LauncherRecentsGate.trailingScanDelayMs(
                nowUptimeMs = 1_000L, lastScanUptimeMs = 900L,
                throttleMs = THROTTLE, marginMs = 50L,
            ),
        ).isEqualTo(250L)
    }

    @Test
    fun trailingDelay_neverNegative() {
        // Residuo già scaduto (clock al bordo): resta il solo margine.
        assertThat(
            LauncherRecentsGate.trailingScanDelayMs(
                nowUptimeMs = 5_000L, lastScanUptimeMs = 900L,
                throttleMs = THROTTLE, marginMs = 50L,
            ),
        ).isEqualTo(50L)
    }

    // ─── advanceInitialBurst (burst robusto a label map non pronta) ─────────

    @Test
    fun burst_mapNotReady_doesNotConsumeAttempt() {
        // Prewarm ancora in corso: il run è un no-op a costo zero e NON
        // brucia il tentativo — il burst deve poter leggere lo zero quando
        // la mappa arriva (prima sessione dopo un process restart).
        val step = LauncherRecentsGate.advanceInitialBurst(
            attemptsConsumed = 0, totalRuns = 1, scanExecuted = false,
            maxAttempts = 3, maxRuns = 8,
        )
        assertThat(step.attemptsConsumed).isEqualTo(0)
        assertThat(step.repost).isTrue()
    }

    @Test
    fun burst_scanExecuted_consumesAttempt_stopsAtMaxAttempts() {
        val mid = LauncherRecentsGate.advanceInitialBurst(
            attemptsConsumed = 1, totalRuns = 2, scanExecuted = true,
            maxAttempts = 3, maxRuns = 8,
        )
        assertThat(mid.attemptsConsumed).isEqualTo(2)
        assertThat(mid.repost).isTrue()

        val last = LauncherRecentsGate.advanceInitialBurst(
            attemptsConsumed = 2, totalRuns = 3, scanExecuted = true,
            maxAttempts = 3, maxRuns = 8,
        )
        assertThat(last.attemptsConsumed).isEqualTo(3)
        assertThat(last.repost).isFalse()
    }

    @Test
    fun burst_totalRunsCap_stopsEvenIfMapNeverReady() {
        // 8° run ancora senza mappa: il cap totale chiude il loop.
        val step = LauncherRecentsGate.advanceInitialBurst(
            attemptsConsumed = 0, totalRuns = 8, scanExecuted = false,
            maxAttempts = 3, maxRuns = 8,
        )
        assertThat(step.attemptsConsumed).isEqualTo(0)
        assertThat(step.repost).isFalse()
    }

    // ─── shouldRearmInitialBurst (rientro nelle recents a sessione viva) ────

    @Test
    fun rearm_blockedWhileBurstPending() {
        assertThat(
            LauncherRecentsGate.shouldRearmInitialBurst(
                burstPending = true, nowUptimeMs = 10_000L, lastScanUptimeMs = 1_000L,
                minIdleMs = 500L,
            ),
        ).isFalse()
    }

    @Test
    fun rearm_blockedWithinIdleWindow() {
        // Scan recentissimo (re-emissione della stessa apertura): no rearm.
        assertThat(
            LauncherRecentsGate.shouldRearmInitialBurst(
                burstPending = false, nowUptimeMs = 1_300L, lastScanUptimeMs = 1_000L,
                minIdleMs = 500L,
            ),
        ).isFalse()
    }

    @Test
    fun rearm_allowedAfterIdle() {
        // Rientro vero: nessun burst in coda, ultimo scan vecchio.
        assertThat(
            LauncherRecentsGate.shouldRearmInitialBurst(
                burstPending = false, nowUptimeMs = 60_000L, lastScanUptimeMs = 1_000L,
                minIdleMs = 500L,
            ),
        ).isTrue()
    }

    // ─── isSessionStillPlausible (sanity-check sessione orfana) ─────────────

    private val SELF = "com.dev.koru"
    private val SKIP = setOf("android", "com.android.systemui", "net.oneplus.launcher")

    @Test
    fun sanity_nullForeground_keepsSession() {
        // UsageStats muto: fail-open, coerente col resto del gate.
        assertThat(LauncherRecentsGate.isSessionStillPlausible(null, SELF, SKIP)).isTrue()
    }

    @Test
    fun sanity_recentsHostForeground_keepsSession() {
        assertThat(
            LauncherRecentsGate.isSessionStillPlausible("net.oneplus.launcher", SELF, SKIP),
        ).isTrue()
    }

    @Test
    fun sanity_realAppForeground_closesSession() {
        assertThat(
            LauncherRecentsGate.isSessionStillPlausible("com.whatsapp", SELF, SKIP),
        ).isFalse()
    }

    @Test
    fun sanity_koruForeground_closesSession() {
        // Nuovo comportamento pinnato: a recents aperte il fg UsageStats è
        // l'HOST, non Koru sottostante → a 60s fg==Koru = recents chiuse
        // senza window event = sessione orfana da chiudere.
        assertThat(LauncherRecentsGate.isSessionStillPlausible(SELF, SELF, SKIP)).isFalse()
    }
}
