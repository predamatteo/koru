package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * SEC-03 — test della decisione PURA [UsageGuardStore.decide], il cuore della
 * guardia monotonica anti clock-backward sul cap giornaliero.
 *
 * Avversario: l'utente che sposta la DATA per azzerare "usato oggi" e sbloccare
 * un'app capata (specie strict/hard cap). Proprietà:
 * - stesso giorno → effettivo = max(raw, accumulato), mai scende;
 * - **salto data INDIETRO** → niente rollover, accumulato portato avanti;
 * - **salto wall in AVANTI incoerente** → niente rollover (no giorno fresco);
 * - **rollover di mezzanotte LEGITTIMO** (clock coerenti) → giorno nuovo, raw;
 * - **reboot** (elapsed→0) → fidati del giorno wall (UsageStats sopravvivono);
 * - primo avvio → inizializza al raw.
 *
 * Tempi in ms. `MIN` = 60_000.
 */
class UsageGuardDecideTest {

    private val min = 60_000L
    private val tol = UsageGuardStore.TIME_DRIFT_TOLERANCE_MS

    @Test
    fun firstObservation_initializesToRaw() {
        val d = UsageGuardStore.decide(
            rawMs = 10 * min,
            savedDay = "", // nessuna entry
            savedAccumMs = 0L,
            realToday = "2026-05-26",
            lastWall = 0L,
            lastElapsed = 0L,
            nowWall = 1_000_000L,
            nowElapsed = 1_000_000L,
        )
        assertThat(d.effectiveMs).isEqualTo(10 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
        assertThat(d.accumMs).isEqualTo(10 * min)
    }

    @Test
    fun sameDay_consistentClocks_accumulatesMax() {
        // Stesso giorno, +5min su entrambi gli orologi; raw cresciuto a 12min.
        val d = UsageGuardStore.decide(
            rawMs = 12 * min,
            savedDay = "2026-05-26",
            savedAccumMs = 10 * min,
            realToday = "2026-05-26",
            lastWall = 1_000_000L,
            lastElapsed = 1_000_000L,
            nowWall = 1_000_000L + 5 * min,
            nowElapsed = 1_000_000L + 5 * min,
        )
        assertThat(d.effectiveMs).isEqualTo(12 * min)
        assertThat(d.accumMs).isEqualTo(12 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }

    @Test
    fun sameDay_rawDropsDueToGlitch_doesNotDecrease() {
        // Raw "sceso" (glitch UsageStats) ma stesso giorno → tiene l'accumulato.
        val d = UsageGuardStore.decide(
            rawMs = 1 * min,
            savedDay = "2026-05-26",
            savedAccumMs = 30 * min,
            realToday = "2026-05-26",
            lastWall = 2_000_000L,
            lastElapsed = 2_000_000L,
            nowWall = 2_000_000L + min,
            nowElapsed = 2_000_000L + min,
        )
        assertThat(d.effectiveMs).isEqualTo(30 * min)
        assertThat(d.accumMs).isEqualTo(30 * min)
    }

    @Test
    fun backwardDateChange_freezesDay_carriesAccumForward() {
        // ATTACCO SEC-03: l'utente porta la data a IERI. realToday torna
        // indietro, raw cade a ~0, ma elapsed è avanzato normalmente.
        // → niente rollover, accumulato (cap già scattato) portato avanti.
        val d = UsageGuardStore.decide(
            rawMs = 0L, // query sulla finestra "ieri" → ~0
            savedDay = "2026-05-26",
            savedAccumMs = 60 * min, // cap di 60min già raggiunto
            realToday = "2026-05-25", // data spostata indietro di 1g
            lastWall = 10_000_000L,
            lastElapsed = 5_000_000L,
            // wall indietro di 1 giorno, elapsed avanti di 10s (stesso boot)
            nowWall = 10_000_000L - 24 * 3_600_000L,
            nowElapsed = 5_000_000L + 10_000L,
        )
        assertThat(d.effectiveMs).isEqualTo(60 * min) // cap RESTA scattato
        assertThat(d.day).isEqualTo("2026-05-26") // giorno congelato
        assertThat(d.accumMs).isEqualTo(60 * min)
    }

    @Test
    fun forwardWallJump_inconsistent_freezesDay() {
        // L'utente salta il wall AVANTI di 2 giorni (a un giorno "fresco" con
        // uso 0) ma elapsed è avanzato di pochi secondi → incoerente → congela.
        val d = UsageGuardStore.decide(
            rawMs = 0L,
            savedDay = "2026-05-26",
            savedAccumMs = 45 * min,
            realToday = "2026-05-28",
            lastWall = 10_000_000L,
            lastElapsed = 5_000_000L,
            nowWall = 10_000_000L + 48 * 3_600_000L, // +2 giorni wall
            nowElapsed = 5_000_000L + 5_000L, // +5s reali
        )
        assertThat(d.effectiveMs).isEqualTo(45 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }

    @Test
    fun legitimateMidnightRollover_consistentClocks_resetsToRaw() {
        // Mezzanotte legittima: device sveglio (o in deep sleep, che elapsed
        // conta), i due delta concordano. Giorno cambia → nuovo giorno, raw.
        val delta = 30 * min
        val d = UsageGuardStore.decide(
            rawMs = 2 * min, // poco uso nel nuovo giorno
            savedDay = "2026-05-25",
            savedAccumMs = 60 * min,
            realToday = "2026-05-26",
            lastWall = 10_000_000L,
            lastElapsed = 5_000_000L,
            nowWall = 10_000_000L + delta,
            nowElapsed = 5_000_000L + delta, // concordano
        )
        assertThat(d.effectiveMs).isEqualTo(2 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
        assertThat(d.accumMs).isEqualTo(2 * min)
    }

    @Test
    fun midnightRollover_withinDriftTolerance_stillRolls() {
        // I due delta differiscono ma entro tolleranza (NTP slew / DST) →
        // rollover ancora considerato legittimo.
        val d = UsageGuardStore.decide(
            rawMs = 3 * min,
            savedDay = "2026-05-25",
            savedAccumMs = 90 * min,
            realToday = "2026-05-26",
            lastWall = 10_000_000L,
            lastElapsed = 5_000_000L,
            nowWall = 10_000_000L + 30 * min + (tol - 1_000L), // entro tolleranza
            nowElapsed = 5_000_000L + 30 * min,
        )
        assertThat(d.effectiveMs).isEqualTo(3 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }

    @Test
    fun reboot_sameDay_trustsWallAccumulates() {
        // Reboot (elapsed regredito a ~0) nello stesso giorno wall → accumula.
        val d = UsageGuardStore.decide(
            rawMs = 40 * min,
            savedDay = "2026-05-26",
            savedAccumMs = 35 * min,
            realToday = "2026-05-26",
            lastWall = 10_000_000L,
            lastElapsed = 9_000_000L,
            nowWall = 10_000_000L + 5 * min,
            nowElapsed = 3_000L, // reboot
        )
        assertThat(d.effectiveMs).isEqualTo(40 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }

    @Test
    fun reboot_acrossMidnight_rollsOver() {
        // Device spento attraverso la mezzanotte poi riacceso: reboot +
        // giorno cambiato → ci fidiamo del giorno wall → rollover.
        val d = UsageGuardStore.decide(
            rawMs = 5 * min,
            savedDay = "2026-05-25",
            savedAccumMs = 60 * min,
            realToday = "2026-05-26",
            lastWall = 10_000_000L,
            lastElapsed = 9_000_000L,
            nowWall = 10_000_000L + 8 * 3_600_000L, // +8h (spento di notte)
            nowElapsed = 2_000L, // reboot
        )
        assertThat(d.effectiveMs).isEqualTo(5 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }

    @Test
    fun noMeta_dayChanged_allowsRollover() {
        // Entry pkg presente ma meta clock assente (record parziale): non
        // possiamo verificare i clock → consenti il rollover (fail verso UX,
        // ma è un caso transitorio; il prossimo check avrà meta fresche).
        val d = UsageGuardStore.decide(
            rawMs = 4 * min,
            savedDay = "2026-05-25",
            savedAccumMs = 60 * min,
            realToday = "2026-05-26",
            lastWall = 0L, // niente meta
            lastElapsed = 0L,
            nowWall = 10_000_000L,
            nowElapsed = 10_000_000L,
        )
        assertThat(d.effectiveMs).isEqualTo(4 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }

    @Test
    fun backwardJump_rawAboveAccum_usesRaw() {
        // Salto indietro ma il raw (per qualche motivo) è > accumulato:
        // usiamo comunque il max → il raw. (Robustezza del max.)
        val d = UsageGuardStore.decide(
            rawMs = 80 * min,
            savedDay = "2026-05-26",
            savedAccumMs = 60 * min,
            realToday = "2026-05-25",
            lastWall = 10_000_000L,
            lastElapsed = 5_000_000L,
            nowWall = 10_000_000L - 24 * 3_600_000L,
            nowElapsed = 5_000_000L + 10_000L,
        )
        assertThat(d.effectiveMs).isEqualTo(80 * min)
        assertThat(d.day).isEqualTo("2026-05-26")
    }
}
