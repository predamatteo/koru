package com.dev.koru.channels

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * SEC-04 — test del calcolo del residuo di lockout
 * ([StrictModeMethodChannel.computeLockoutRemainingMs]), ancorato a un clock
 * monotonico reboot-corrected.
 *
 * Proprietà verificate (avversario = utente che muove l'orologio per
 * accorciare il lockout del backdoor brute-force):
 * - stesso boot, nessuna manomissione → progresso = tempo monotonico reale;
 * - **salto WALL in avanti** non accorcia (vince il delta monotonico);
 * - **salto WALL indietro** non accorcia (progresso ridotto → più lockout);
 * - `last_fail_wall` nel FUTURO (manomissione) → residuo PIENO, mai 0;
 * - **reboot** gestito: con wall avanzato normalmente il lockout scade;
 * - reboot + wall indietro → residuo pieno;
 * - record incompleto/legacy → fail-secure.
 *
 * Tutti i tempi sono in ms. `LOCK = 5 min` per leggibilità.
 */
class StrictModeLockoutTest {

    private val lock = 5L * 60_000L // 5 minuti

    /// Helper: stesso boot ⇒ bootWall identico tra fail e now.
    private fun sameBoot(
        lastFailElapsed: Long,
        lastFailWall: Long,
        nowElapsed: Long,
        nowWall: Long,
    ): Long {
        val bootWall = lastFailWall - lastFailElapsed
        // Forziamo l'ancora "now" coerente col bootWall del fail (stesso boot)
        // a meno che il chiamante voglia simulare un wall jump: in quel caso
        // nowWall/nowElapsed sono passati espliciti e il bootWall "now" derivato
        // (nowWall-nowElapsed) può divergere — è esattamente ciò che testiamo.
        return StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = lastFailElapsed,
            lastFailWall = lastFailWall,
            lastFailBootWall = bootWall,
            nowElapsed = nowElapsed,
            nowWall = nowWall,
        )
    }

    @Test
    fun sameBoot_noTampering_progressesByMonotonicTime() {
        // Fail a elapsed=100_000, wall=1_000_000. 2 min dopo su ENTRAMBI.
        val r = sameBoot(
            lastFailElapsed = 100_000L,
            lastFailWall = 1_000_000L,
            nowElapsed = 100_000L + 120_000L,
            nowWall = 1_000_000L + 120_000L,
        )
        // Trascorsi 2 min su 5 → restano 3 min.
        assertThat(r).isEqualTo(lock - 120_000L)
    }

    @Test
    fun sameBoot_wallJumpForward_doesNotShortenLockout() {
        // Monotonico avanzato di soli 10s, ma l'utente spinge il WALL avanti di
        // 10 min per "superare" i 5 min di lockout. Deve vincere elapsedDelta.
        val r = sameBoot(
            lastFailElapsed = 100_000L,
            lastFailWall = 1_000_000L,
            nowElapsed = 100_000L + 10_000L, // +10s reali
            nowWall = 1_000_000L + 600_000L, // +10min wall (tamper)
        )
        // Progresso = min(10s, 10min) = 10s → restano ~4min50s.
        assertThat(r).isEqualTo(lock - 10_000L)
    }

    @Test
    fun sameBoot_wallJumpBackward_doesNotShortenLockout() {
        // Monotonico avanzato di 2 min; l'utente sposta il WALL INDIETRO di 1
        // min (wallDelta = +1min). min(2min,1min)=1min → progresso ridotto →
        // PIÙ lockout residuo (fail-secure), mai meno di quanto dovuto.
        val r = sameBoot(
            lastFailElapsed = 100_000L,
            lastFailWall = 1_000_000L,
            nowElapsed = 100_000L + 120_000L, // +2min reali
            nowWall = 1_000_000L + 60_000L, // +1min wall
        )
        assertThat(r).isEqualTo(lock - 60_000L) // usa il minore (1min)
    }

    @Test
    fun sameBoot_wallMovedBeforeFail_fullRemaining() {
        // L'utente porta il wall PRIMA dell'istante del fail (wallDelta<0).
        // Anche se elapsedDelta>0, min(...) è negativo → clamp a 0 → PIENO.
        val r = sameBoot(
            lastFailElapsed = 100_000L,
            lastFailWall = 1_000_000L,
            nowElapsed = 100_000L + 120_000L,
            nowWall = 900_000L, // 100s PRIMA del fail
        )
        assertThat(r).isEqualTo(lock)
    }

    @Test
    fun futureDatedLastFailWall_yieldsFullRemaining_neverZero() {
        // last_fail_wall nel FUTURO rispetto a now (sintomo di manomissione):
        // wallDelta<0 → progresso 0 → residuo PIENO. Mai 0 (non sblocca).
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 100_000L,
            lastFailWall = 5_000_000L, // futuro
            lastFailBootWall = 5_000_000L - 100_000L,
            nowElapsed = 100_000L + 120_000L,
            nowWall = 1_000_000L, // ben prima del fail "futuro"
        )
        assertThat(r).isEqualTo(lock)
    }

    @Test
    fun sameBoot_lockoutFullyElapsed_returnsZero() {
        val r = sameBoot(
            lastFailElapsed = 100_000L,
            lastFailWall = 1_000_000L,
            nowElapsed = 100_000L + lock + 1_000L, // oltre i 5 min
            nowWall = 1_000_000L + lock + 1_000L,
        )
        assertThat(r).isEqualTo(0L)
    }

    @Test
    fun reboot_wallAdvancedNormally_lockoutExpires() {
        // Reboot: elapsed riparte da ~0 (nowElapsed piccolo < lastFailElapsed)
        // e l'ancora di boot cambia. Il wall è avanzato di 6 min (device spento
        // + acceso). Si usa wallDelta → lockout (5min) scaduto → 0.
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 500_000L,
            lastFailWall = 1_000_000L,
            lastFailBootWall = 1_000_000L - 500_000L, // 500_000
            nowElapsed = 2_000L, // appena riavviato
            nowWall = 1_000_000L + 360_000L, // +6min wall
        )
        assertThat(r).isEqualTo(0L)
    }

    @Test
    fun reboot_wallAdvancedPartially_remainingFromWall() {
        // Reboot con wall avanzato di soli 2 min → restano 3 min.
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 500_000L,
            lastFailWall = 1_000_000L,
            lastFailBootWall = 500_000L,
            nowElapsed = 2_000L,
            nowWall = 1_000_000L + 120_000L,
        )
        assertThat(r).isEqualTo(lock - 120_000L)
    }

    @Test
    fun reboot_wallMovedBackward_fullRemaining() {
        // Reboot E wall portato indietro → wallDelta<0 → progresso 0 → PIENO.
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 500_000L,
            lastFailWall = 1_000_000L,
            lastFailBootWall = 500_000L,
            nowElapsed = 2_000L,
            nowWall = 900_000L, // indietro rispetto al fail
        )
        assertThat(r).isEqualTo(lock)
    }

    @Test
    fun missingAnchors_failSecureFullRemaining() {
        // Record senza last_fail_wall (0) → non possiamo fidarci di nulla →
        // lockout pieno (fail-secure).
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 0L,
            lastFailWall = 0L,
            lastFailBootWall = 0L,
            nowElapsed = 10_000_000L,
            nowWall = 10_000_000L,
        )
        assertThat(r).isEqualTo(lock)
    }

    @Test
    fun legacyRecord_sameBoot_usesMonotonic() {
        // Record pre-SEC-04: lastFailBootWall=0 ma elapsed NON regredito →
        // stesso boot → si usa min(elapsedDelta, wallDelta). +2min → restano 3.
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 100_000L,
            lastFailWall = 1_000_000L,
            lastFailBootWall = 0L, // assente (legacy)
            nowElapsed = 100_000L + 120_000L,
            nowWall = 1_000_000L + 120_000L,
        )
        assertThat(r).isEqualTo(lock - 120_000L)
    }

    @Test
    fun legacyRecord_reboot_usesWall() {
        // Record legacy (bootWall=0) E reboot (elapsed regredito): il ramo
        // reboot considera bootWall<=0 come "cambiato" → usa wallDelta. Wall
        // +2min → restano 3.
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 500_000L,
            lastFailWall = 1_000_000L,
            lastFailBootWall = 0L, // assente (legacy)
            nowElapsed = 2_000L, // reboot: elapsed regredito
            nowWall = 1_000_000L + 120_000L,
        )
        assertThat(r).isEqualTo(lock - 120_000L)
    }

    @Test
    fun monotonicRegressedButBootUnchanged_anomaly_failSecure() {
        // Elapsed regredito ma ancora di boot INVARIATA: scenario anomalo
        // (corruzione / record manomesso) → fail-secure, lockout pieno.
        // bootWall del fail = 1_000_000 - 500_000 = 500_000; teniamo
        // nowBootWall = nowWall - nowElapsed ≈ 500_000 (entro tolleranza).
        val r = StrictModeMethodChannel.computeLockoutRemainingMs(
            lockoutDuration = lock,
            lastFailElapsed = 500_000L,
            lastFailWall = 1_000_000L,
            lastFailBootWall = 500_000L,
            nowElapsed = 100_000L, // regredito (era 500_000)
            nowWall = 600_000L, // 600_000 - 100_000 = 500_000 == bootWall fail
        )
        assertThat(r).isEqualTo(lock)
    }
}
