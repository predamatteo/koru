package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * SEC-05 — il counter di friction NON si azzera su un salto wall in avanti dopo
 * un reboot. Test della decisione PURA [BypassCountStore.decideDay] nei casi che
 * coinvolgono il reboot (elapsedRealtime regredito a ~0).
 *
 * Attacco: l'utente riavvia il device e sposta la DATA in avanti (a un giorno
 * "fresco" con friction 0) per ottenere countdown brevi / durate lunghe sul
 * bypass di un'app capata non-strict. Il vecchio codice, rilevato il reboot, si
 * fidava CIECAMENTE del wall → giorno fresco → friction azzerata.
 *
 * Fix: post-reboot si crede al giorno wall solo se l'avanzamento è plausibile per
 * il tempo realmente spento (<= [BypassCountStore.MAX_PLAUSIBLE_OFF_MS]).
 * Oltre quella soglia (o per un wall NEGATIVO) si congela al giorno salvato →
 * counter NON azzerato → più frizione (direzione fail-secure).
 *
 * Tempi in ms.
 */
class BypassCountDecideDaySec05Test {

    private val hour = 3_600_000L
    private val day = 24 * hour
    private val maxOff = BypassCountStore.MAX_PLAUSIBLE_OFF_MS

    private fun meta(day: String, wall: Long, elapsed: Long) =
        BypassCountStore.Meta(lastResetDay = day, lastWall = wall, lastElapsed = elapsed)

    @Test
    fun rebootPlusLargeForwardWallJump_freezesDay_keepsFriction() {
        // CUORE SEC-05: reboot (elapsed ~0) + data spostata avanti di 5 giorni
        // (>> tempo spento plausibile) → NON rollover, giorno congelato → la
        // friction accumulata resta in vigore.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-31", // giorno "fresco" forgiato
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 9_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L + 5 * day, // +5 giorni wall
            nowElapsed = 2_000L, // reboot
        )
        assertThat(d).isEqualTo("2026-05-26") // congelato → counter NON azzerato
    }

    @Test
    fun rebootJustOverPlausibleThreshold_freezesDay() {
        // Appena oltre la soglia di plausibilità → ancora fail-secure (congela).
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-30",
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 9_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L + maxOff + hour, // soglia + 1h
            nowElapsed = 1_000L, // reboot
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun rebootWithinPlausibleOffTime_acrossMidnight_rollsOver() {
        // Caso LEGITTIMO: device spento per la notte (8h) e riacceso il giorno
        // dopo. Reboot + avanzamento wall plausibile (<= soglia) → rollover.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-27",
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 9_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L + 8 * hour, // spento ~8h
            nowElapsed = 2_000L, // reboot
        )
        assertThat(d).isEqualTo("2026-05-27") // rollover legittimo
    }

    @Test
    fun rebootSameDay_staysSameDay() {
        // Reboot nello stesso giorno wall: nessun cambio di giorno da decidere →
        // il primo guard (savedDay == rawToday) ritorna subito il giorno salvato.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-26",
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 9_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L + 5 * hour,
            nowElapsed = 2_000L, // reboot
        )
        assertThat(d).isEqualTo("2026-05-26")
    }

    @Test
    fun rebootWithBackwardWallAcrossDay_freezesDay() {
        // Reboot + data riportata INDIETRO (wallDelta negativo) → mai rollover a
        // un giorno passato; congela al giorno salvato.
        val d = BypassCountStore.decideDay(
            rawToday = "2026-05-25",
            meta = meta("2026-05-26", wall = 10_000_000L, elapsed = 9_000_000L),
            latestSavedDate = "2026-05-26",
            nowWall = 10_000_000L - day, // wall indietro di 1 giorno
            nowElapsed = 2_000L, // reboot
        )
        assertThat(d).isEqualTo("2026-05-26")
    }
}
