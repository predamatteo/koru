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
}
