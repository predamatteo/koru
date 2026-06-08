package com.dev.koru.service

import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI (JUnit + Truth, niente Robolectric) di [BlockPolicyEvaluator]:
 * - [BlockPolicyEvaluator.isNowInInterval]: tutti i boundary degli intervalli;
 * - [BlockPolicyEvaluator.isProfileActiveNow]: matrice pausa/giorno/onUntil/
 *   time-bit/wifi.
 *
 * Questi pin la SEMANTICA CANONICA condivisa da tutti e 4 i decision site
 * native + il "active now" lato Dart. Una futura divergenza (es. qualcuno
 * reintroduce intervalli chiusi nel backup) fa fallire qui.
 *
 * Convenzioni: minuti-del-giorno 0..1439; `MON` = bit del lunedì (1).
 */
class BlockPolicyEvaluatorActiveNowTest {

    private val MON = 1
    private val TUE = 2

    /** Profilo "tutto attivo" di default; i test sovrascrivono solo ciò che testano. */
    private fun profile(
        typeCombinations: Int = 0,
        dayFlags: Int = MON,
        onUntil: Long = 0L,
        pausedUntil: Long = 0L,
        blockingMode: Int = 0,
    ) = NativeProfile(
        id = 1,
        title = "P",
        typeCombinations = typeCombinations,
        onConditions = 0,
        operator = 0,
        dayFlags = dayFlags,
        blockNotifications = false,
        blockLaunch = false,
        isEnabled = true,
        isLocked = false,
        onUntil = onUntil,
        lockedUntil = 0L,
        pausedUntil = pausedUntil,
        blockingMode = blockingMode,
        blockUnsupportedBrowsers = false,
        blockAdultContent = false,
        colorHex = "#5C8262",
        emoji = "X",
    )

    private fun interval(from: Int, to: Int) = NativeInterval(1, 1, from, to, true)

    private fun activeNow(
        profile: NativeProfile,
        intervals: List<NativeInterval> = emptyList(),
        wifiSet: Set<String>? = null,
        nowWallMs: Long = 1_000L,
        nowMinutesOfDay: Int = 12 * 60,
        todayDayFlag: Int = MON,
        currentWifiSsid: String? = null,
    ): Boolean = BlockPolicyEvaluator.isProfileActiveNow(
        profile, intervals, wifiSet, nowWallMs, nowMinutesOfDay, todayDayFlag, currentWifiSsid,
    )

    // ---- isNowInInterval: boundary ------------------------------------------

    @Test
    fun interval_halfOpen_startInclusive_endExclusive() {
        val from = 9 * 60
        val to = 17 * 60
        assertThat(BlockPolicyEvaluator.isNowInInterval(from - 1, from, to)).isFalse()
        assertThat(BlockPolicyEvaluator.isNowInInterval(from, from, to)).isTrue()
        assertThat(BlockPolicyEvaluator.isNowInInterval(to - 1, from, to)).isTrue()
        assertThat(BlockPolicyEvaluator.isNowInInterval(to, from, to)).isFalse()
    }

    @Test
    fun interval_fromEqualsTo_is24h() {
        // from == to ⇒ sempre dentro (canonico). Era 1-min nel backup, "mai"
        // lato Dart: ora allineati a 24h ovunque.
        assertThat(BlockPolicyEvaluator.isNowInInterval(0, 600, 600)).isTrue()
        assertThat(BlockPolicyEvaluator.isNowInInterval(600, 600, 600)).isTrue()
        assertThat(BlockPolicyEvaluator.isNowInInterval(1439, 600, 600)).isTrue()
    }

    @Test
    fun interval_crossMidnight_22to06() {
        val from = 22 * 60
        val to = 6 * 60
        assertThat(BlockPolicyEvaluator.isNowInInterval(22 * 60, from, to)).isTrue() // start
        assertThat(BlockPolicyEvaluator.isNowInInterval(23 * 60 + 30, from, to)).isTrue()
        assertThat(BlockPolicyEvaluator.isNowInInterval(0, from, to)).isTrue() // midnight
        assertThat(BlockPolicyEvaluator.isNowInInterval(5 * 60 + 59, from, to)).isTrue()
        assertThat(BlockPolicyEvaluator.isNowInInterval(6 * 60, from, to)).isFalse() // to exclusive
        assertThat(BlockPolicyEvaluator.isNowInInterval(12 * 60, from, to)).isFalse() // midday
        assertThat(BlockPolicyEvaluator.isNowInInterval(from - 1, from, to)).isFalse()
    }

    // ---- minutesUntilNextBoundary -------------------------------------------

    @Test
    fun nextBoundary_twoWindows_beforeSecondStart() {
        // 09-13 e 14-18; ore 13:57 (837') → prossimo confine = inizio 14:00 fra 3'.
        val intervals = listOf(interval(9 * 60, 13 * 60), interval(14 * 60, 18 * 60))
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(13 * 60 + 57, intervals))
            .isEqualTo(3)
    }

    @Test
    fun nextBoundary_exactlyOnBoundary_skipsToNext() {
        // Ore 14:00 esatte (inizio finestra): il confine "ora" vale 1440, non 0,
        // quindi il prossimo confine è la FINE 18:00 fra 240'.
        val intervals = listOf(interval(9 * 60, 13 * 60), interval(14 * 60, 18 * 60))
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(14 * 60, intervals))
            .isEqualTo(240)
    }

    @Test
    fun nextBoundary_insideWindow_returnsEnd() {
        // Dentro 09-13 alle 12:59 → prossimo confine = fine 13:00 fra 1'.
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(12 * 60 + 59, listOf(interval(9 * 60, 13 * 60))))
            .isEqualTo(1)
    }

    @Test
    fun nextBoundary_emptyList_null() {
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(12 * 60, emptyList())).isNull()
    }

    @Test
    fun nextBoundary_only24hInterval_null() {
        // from == to ⇒ 24h, nessun confine significativo.
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(12 * 60, listOf(interval(600, 600))))
            .isNull()
    }

    @Test
    fun nextBoundary_crossMidnight_picksNearest() {
        // Finestra 22:00-06:00 (1320,360). Alle 23:00 (1380') il confine più
        // vicino è la FINE 06:00 del giorno dopo, fra 420'.
        val intervals = listOf(interval(22 * 60, 6 * 60))
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(23 * 60, intervals)).isEqualTo(420)
        // Alle 05:00 (300') il confine più vicino è la fine 06:00, fra 60'.
        assertThat(BlockPolicyEvaluator.minutesUntilNextBoundary(5 * 60, intervals)).isEqualTo(60)
    }

    // ---- isProfileActiveNow: matrice ----------------------------------------

    @Test
    fun activeNow_noConstraints_active() {
        assertThat(activeNow(profile())).isTrue()
    }

    @Test
    fun activeNow_pausedUntilNegative_inactive() {
        assertThat(activeNow(profile(pausedUntil = -1L))).isFalse()
    }

    @Test
    fun activeNow_pausedUntilFuture_inactive() {
        assertThat(activeNow(profile(pausedUntil = 5_000L), nowWallMs = 1_000L)).isFalse()
    }

    @Test
    fun activeNow_pausedUntilPast_active() {
        // pausedUntil nel passato (>0 ma < now) ⇒ pausa scaduta ⇒ attivo.
        assertThat(activeNow(profile(pausedUntil = 500L), nowWallMs = 1_000L)).isTrue()
    }

    @Test
    fun activeNow_dayFlagMismatch_inactive() {
        assertThat(activeNow(profile(dayFlags = MON), todayDayFlag = TUE)).isFalse()
    }

    @Test
    fun activeNow_onUntilExpired_inactive() {
        assertThat(activeNow(profile(onUntil = 900L), nowWallMs = 1_000L)).isFalse()
    }

    @Test
    fun activeNow_onUntilFuture_active() {
        assertThat(activeNow(profile(onUntil = 2_000L), nowWallMs = 1_000L)).isTrue()
    }

    @Test
    fun activeNow_timeBitOff_intervalIgnored() {
        // Niente bit TIME ⇒ gli intervals non gating-ano: attivo anche fuori finestra.
        assertThat(
            activeNow(
                profile(typeCombinations = 0),
                intervals = listOf(interval(9 * 60, 10 * 60)),
                nowMinutesOfDay = 12 * 60,
            ),
        ).isTrue()
    }

    @Test
    fun activeNow_timeBitOn_emptyIntervals_active() {
        // Bit TIME ON ma nessun interval ⇒ nessun gating temporale ⇒ attivo.
        assertThat(
            activeNow(
                profile(typeCombinations = 1),
                intervals = emptyList(),
            ),
        ).isTrue()
    }

    @Test
    fun activeNow_timeBitOn_outsideInterval_inactive() {
        assertThat(
            activeNow(
                profile(typeCombinations = 1),
                intervals = listOf(interval(9 * 60, 10 * 60)),
                nowMinutesOfDay = 12 * 60,
            ),
        ).isFalse()
    }

    @Test
    fun activeNow_timeBitOn_insideInterval_active() {
        assertThat(
            activeNow(
                profile(typeCombinations = 1),
                intervals = listOf(interval(9 * 60, 18 * 60)),
                nowMinutesOfDay = 12 * 60,
            ),
        ).isTrue()
    }

    @Test
    fun activeNow_wifiSet_matches_active() {
        assertThat(
            activeNow(profile(), wifiSet = setOf("Home"), currentWifiSsid = "Home"),
        ).isTrue()
    }

    @Test
    fun activeNow_wifiSet_mismatch_inactive() {
        assertThat(
            activeNow(profile(), wifiSet = setOf("Home"), currentWifiSsid = "Office"),
        ).isFalse()
    }

    @Test
    fun activeNow_wifiSet_nullSsid_inactive() {
        // SSID non leggibile (permesso location off) ⇒ fail-secure ⇒ inattivo.
        assertThat(
            activeNow(profile(), wifiSet = setOf("Home"), currentWifiSsid = null),
        ).isFalse()
    }

    @Test
    fun activeNow_emptyWifiSet_noConstraint_active() {
        assertThat(
            activeNow(profile(), wifiSet = emptySet(), currentWifiSsid = null),
        ).isTrue()
    }
}
