package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test della decisione PURA [BypassCountStore.decideDay] — la guardia anti
 * clock-abuse sul rollover di giorno del friction counter.
 *
 * Avversario: l'utente che sposta la DATA per "guadagnare" un giorno fresco e
 * azzerare la friction progressiva (countdown / durate del bypass). Direzione
 * fail-secure: in caso di ambiguità si congela al giorno salvato → counter NON
 * azzerato → più frizione, mai meno.
 *
 * Tempi in ms. `MIN` = 60_000. La logica specifica del reboot+salto-avanti
 * (SEC-05) è coperta in [BypassCountDecideDaySec05Test].
 */
class BypassCountDecideDayTest {

    private val min = 60_000L
    private val tol = BypassCountStore.TIME_DRIFT_TOLERANCE_MS

    private fun meta(day: String, wall: Long, elapsed: Long) =
        BypassCountStore.Meta(lastResetDay = day, lastWall = wall, lastElapsed = elapsed)

    @Test
    fun noMeta_usesRawToday() {
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-26",
            meta = null,
            latestSavedDate = "2020-01-01",
            nowWall = 1_000_000L,
            nowElapsed = 1_000_000L,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun metaWithoutClockBaseline_usesRawToday() {
        // Meta presente ma senza baseline temporale (record parziale) → raw.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-26",
            meta = meta("2026-05-25", wall = 0L, elapsed = 0L),
            latestSavedDate = "2026-05-25",
            nowWall = 1_000_000L,
            nowElapsed = 1_000_000L,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun sameDay_returnsSavedDay() {
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-26",
            meta = meta("2026-05-26", wall = 1_000_000L, elapsed = 1_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 1_000_000L + 5 * min,
            nowElapsed = 1_000_000L + 5 * min,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun backwardWallJump_sameBoot_freezesDay() {
        // L'utente porta la data a IERI per azzerare la friction. Wall indietro
        // di 1 giorno, elapsed avanti normalmente (stesso boot) → congela.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-25",
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 5_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L - 24 * 3_600_000L,
            nowElapsed = 5_000_000L + 10_000L,
        )
        assertThat(d).isEqualTo("2026-05-26") // giorno congelato → counter resta
    }

    @Test
    fun forwardWallJump_sameBoot_inconsistent_freezesDay() {
        // Salto wall avanti di 2 giorni ma elapsed avanzato di pochi secondi
        // (stesso boot) → incoerente → congela (no giorno fresco).
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-28",
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 5_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L + 48 * 3_600_000L,
            nowElapsed = 5_000_000L + 5_000L,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun legitimateMidnightRollover_consistentClocks_rolls() {
        // Mezzanotte legittima: i due delta concordano → nuovo giorno.
        val delta = 30 * min
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-26",
            meta = meta("2026-05-25", wall = 10_000_000L, elapsed = 5_000_000L),
            latestSavedDate = "2026-05-25",
            nowWall = 10_000_000L + delta,
            nowElapsed = 5_000_000L + delta,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun midnightRollover_withinDriftTolerance_stillRolls() {
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-26",
            meta = meta("2026-05-25", wall = 10_000_000L, elapsed = 5_000_000L),
            latestSavedDate = "2026-05-25",
            nowWall = 10_000_000L + 30 * min + (tol - 1_000L),
            nowElapsed = 5_000_000L + 30 * min,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun savedDayFallsBackToLatestSavedDate_whenMetaDayEmpty() {
        // Meta con baseline temporale valida ma lastResetDay vuoto: il giorno
        // salvato si deduce dall'ultima `date` degli entry. Backward jump →
        // congela a quel giorno.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-25",
            meta = meta("", wall = 10_000_000L, elapsed = 5_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L - 24 * 3_600_000L,
            nowElapsed = 5_000_000L + 10_000L,
        )
        assertThat(d).isEqualTo("2026-05-26")
    }
}
