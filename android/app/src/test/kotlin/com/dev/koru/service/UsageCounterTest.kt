package com.dev.koru.service

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import java.util.Calendar
import org.junit.Test

/**
 * Tests for [UsageCounter].
 *
 * The full state-machine in [UsageCounter.foregroundMsPerPackage] is
 * exercised on instrumented devices because `UsageEvents` is an aapt-private
 * sealed type that is awkward to fake from JUnit. Here we cover:
 *
 *  - the private [UsageCounter.clippedSpan] helper (via reflection),
 *  - the error path: when [UsageStatsManager.queryEvents] throws, the public
 *    [UsageCounter.foregroundMsPerPackage] returns an empty map,
 *  - the missing-service path: when the system returns no UsageStatsManager
 *    we still get an empty map (graceful degradation).
 *
 * No Robolectric is needed — we mock the Context directly via MockK.
 */
class UsageCounterTest {

    // -------- Reflection helper --------

    private fun clippedSpan(from: Long, to: Long, windowStart: Long, windowEnd: Long): Long {
        val m = UsageCounter::class.java.getDeclaredMethod(
            "clippedSpan",
            java.lang.Long.TYPE,
            java.lang.Long.TYPE,
            java.lang.Long.TYPE,
            java.lang.Long.TYPE,
        )
        m.isAccessible = true
        return m.invoke(UsageCounter, from, to, windowStart, windowEnd) as Long
    }

    // -------- clippedSpan --------

    @Test
    fun clippedSpan_startClippedToWindowStart() {
        // from=0, to=100, window=[50,200] → clipped to [50,100] → 50.
        assertThat(clippedSpan(0L, 100L, 50L, 200L)).isEqualTo(50L)
    }

    @Test
    fun clippedSpan_negativeFromClippedToWindowStart() {
        // from=-50 < window=0 → clamped to 0. to=100. Span = 100.
        assertThat(clippedSpan(-50L, 100L, 0L, 200L)).isEqualTo(100L)
    }

    @Test
    fun clippedSpan_invertedRangeCoercedToZero() {
        // from=150 > to=50 → clipped span coerced to 0.
        assertThat(clippedSpan(150L, 50L, 0L, 200L)).isEqualTo(0L)
    }

    @Test
    fun clippedSpan_zeroLengthInput_returnsZero() {
        assertThat(clippedSpan(0L, 0L, 0L, 200L)).isEqualTo(0L)
    }

    @Test
    fun clippedSpan_endClippedToWindowEnd() {
        // from=100, to=300, window=[0,200] → clipped to [100,200] → 100.
        assertThat(clippedSpan(100L, 300L, 0L, 200L)).isEqualTo(100L)
    }

    @Test
    fun clippedSpan_fullyInsideWindow_returnsFullSpan() {
        assertThat(clippedSpan(50L, 150L, 0L, 200L)).isEqualTo(100L)
    }

    @Test
    fun clippedSpan_fullyOutsideAfterWindow_returnsZero() {
        assertThat(clippedSpan(300L, 500L, 0L, 200L)).isEqualTo(0L)
    }

    @Test
    fun clippedSpan_fullyOutsideBeforeWindow_returnsZero() {
        assertThat(clippedSpan(-200L, -100L, 0L, 200L)).isEqualTo(0L)
    }

    // -------- foregroundMsPerPackage error paths --------

    @Test
    fun foregroundMsPerPackage_missingUsageService_returnsEmpty() {
        val ctx = mockk<Context>(relaxed = true)
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns null
        val result = UsageCounter.foregroundMsPerPackage(ctx, 0L, 1000L)
        assertThat(result).isEmpty()
    }

    @Test
    fun foregroundMsPerPackage_queryEventsThrows_returnsEmpty() {
        val ctx = mockk<Context>(relaxed = true)
        val usm = mockk<UsageStatsManager>()
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns usm
        every { usm.queryEvents(any(), any()) } throws RuntimeException("simulated")

        val result = UsageCounter.foregroundMsPerPackage(ctx, 0L, 1000L)
        assertThat(result).isEmpty()
    }

    @Test
    fun foregroundMsPerPackage_noEvents_returnsEmpty() {
        val ctx = mockk<Context>(relaxed = true)
        val usm = mockk<UsageStatsManager>()
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns usm

        val events = mockk<UsageEvents>(relaxed = true)
        every { events.hasNextEvent() } returns false
        every { usm.queryEvents(any(), any()) } returns events

        val result = UsageCounter.foregroundMsPerPackage(ctx, 0L, 1000L)
        assertThat(result).isEmpty()
    }

    // -------- todayForegroundMs --------

    @Test
    fun todayForegroundMs_missingService_returnsZero() {
        val ctx = mockk<Context>(relaxed = true)
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns null
        assertThat(UsageCounter.todayForegroundMs(ctx, "com.x")).isEqualTo(0L)
    }

    @Test
    fun todayForegroundMs_queryEventsThrows_returnsZero() {
        val ctx = mockk<Context>(relaxed = true)
        val usm = mockk<UsageStatsManager>()
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns usm
        every { usm.queryEvents(any(), any()) } throws RuntimeException("nope")
        assertThat(UsageCounter.todayForegroundMs(ctx, "com.x")).isEqualTo(0L)
    }

    // -------- splitByLocalDay --------

    @Test
    fun splitByLocalDay_invertedOrZeroWindow_returnsEmpty() {
        assertThat(UsageCounter.splitByLocalDay(100L, 100L)).isEmpty()
        assertThat(UsageCounter.splitByLocalDay(200L, 100L)).isEmpty()
    }

    @Test
    fun splitByLocalDay_withinSingleDay_returnsOneSegment() {
        val cal = Calendar.getInstance().apply {
            set(2026, Calendar.MAY, 12, 10, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val from = cal.timeInMillis
        val to = from + 30L * 60_000 // +30 min, same day
        val res = UsageCounter.splitByLocalDay(from, to)
        assertThat(res).hasSize(1)
        assertThat(res[0].second).isEqualTo(30L * 60_000)
    }

    @Test
    fun splitByLocalDay_crossingMidnight_splitsIntoTwoDays() {
        val cal = Calendar.getInstance().apply {
            set(2026, Calendar.MAY, 12, 23, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val from = cal.timeInMillis // 23:00
        val to = from + 2L * 60 * 60_000 // 01:00 next day (+2h)
        val res = UsageCounter.splitByLocalDay(from, to)
        assertThat(res).hasSize(2)
        // 1h before midnight on day 1, 1h after on day 2 (no DST in May).
        assertThat(res[0].second).isEqualTo(60L * 60_000)
        assertThat(res[1].second).isEqualTo(60L * 60_000)
        assertThat(res[1].first).isGreaterThan(res[0].first)
    }

    @Test
    fun splitByLocalDay_segmentsTileTheWholeWindow() {
        val cal = Calendar.getInstance().apply {
            set(2026, Calendar.MAY, 12, 8, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val from = cal.timeInMillis
        val to = from + 40L * 60 * 60_000 // 40h spans 3 local days
        val res = UsageCounter.splitByLocalDay(from, to)
        assertThat(res.size).isAtLeast(2)
        assertThat(res.sumOf { it.second }).isEqualTo(to - from)
    }

    // -------- foregroundMsPerPackagePerDay error paths --------

    @Test
    fun foregroundMsPerPackagePerDay_missingService_returnsEmpty() {
        val ctx = mockk<Context>(relaxed = true)
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns null
        assertThat(UsageCounter.foregroundMsPerPackagePerDay(ctx, 0L, 1000L))
            .isEmpty()
    }

    @Test
    fun foregroundMsPerPackagePerDay_queryEventsThrows_returnsEmpty() {
        val ctx = mockk<Context>(relaxed = true)
        val usm = mockk<UsageStatsManager>()
        every { ctx.getSystemService(Context.USAGE_STATS_SERVICE) } returns usm
        every { usm.queryEvents(any(), any()) } throws RuntimeException("simulated")
        assertThat(UsageCounter.foregroundMsPerPackagePerDay(ctx, 0L, 1000L))
            .isEmpty()
    }
}
