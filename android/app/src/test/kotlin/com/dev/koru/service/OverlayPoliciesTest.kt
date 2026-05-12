package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.dev.koru.overlay.OverlayConfig
import com.google.common.truth.Truth.assertThat
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [OverlayPolicies.buildUsageLimitOverlay].
 *
 * Strict path is independent of the BypassCountStore — we assert that the
 * `allowBypassAfterCountdown` is forced to false and the BypassPolicy is
 * the default one.
 *
 * Non-strict path varies countdown and durations based on
 * [BypassCountStore.todayCount]: we pre-increment via the real store and
 * reset its in-memory cache between tests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OverlayPoliciesTest {

    private val bypassFile = "koru_bypass_counts.json"
    private val pkg = "com.example.app"

    @Before
    fun setUp() {
        clearBypassState()
    }

    @After
    fun tearDown() {
        clearBypassState()
    }

    private fun clearBypassState() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, bypassFile).delete()
        val field = BypassCountStore::class.java.getDeclaredField("cache")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val cache = field.get(BypassCountStore) as AtomicReference<Any?>
        cache.set(null)
    }

    private fun incrementCount(times: Int) {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        repeat(times) { BypassCountStore.increment(ctx, pkg) }
    }

    // -------- Strict path --------

    @Test
    fun strict_forcesNoBypass_andDefaultPolicy() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val (config, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = true,
        )
        assertThat(config.allowBypassAfterCountdown).isFalse()
        // Default BypassPolicy: countToday=0, no override, pauseAllowed=true.
        assertThat(policy.countToday).isEqualTo(0)
        assertThat(policy.countdownSecondsOverride).isNull()
        assertThat(policy.pauseAllowed).isTrue()
        assertThat(policy.durations).isEqualTo(defaultBypassDurations)
    }

    @Test
    fun strict_ignoresBypassCount() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Pre-load BypassCountStore with 5 increments — strict path must
        // not consult it.
        incrementCount(5)
        val (config, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = true,
        )
        assertThat(config.allowBypassAfterCountdown).isFalse()
        assertThat(policy.countToday).isEqualTo(0)
        assertThat(policy.countdownSecondsOverride).isNull()
    }

    @Test
    fun strict_preservesBaseConfigBranding() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val baseConfig = OverlayConfig(
            backgroundColorArgb = 0xFF112233.toInt(),
            messageTitle = "Custom title",
            messageSubtitle = "Custom subtitle",
            countdownSeconds = 30,
            shakeEnabled = true,
            allowBypassAfterCountdown = true, // will be overridden by strict
        )
        val (config, _) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = true,
            baseConfig = baseConfig,
        )
        assertThat(config.backgroundColorArgb).isEqualTo(0xFF112233.toInt())
        assertThat(config.messageTitle).isEqualTo("Custom title")
        assertThat(config.messageSubtitle).isEqualTo("Custom subtitle")
        assertThat(config.countdownSeconds).isEqualTo(30)
        assertThat(config.shakeEnabled).isTrue()
        // Only allowBypassAfterCountdown is forced.
        assertThat(config.allowBypassAfterCountdown).isFalse()
    }

    // -------- Non-strict path --------

    @Test
    fun nonStrict_countZero_countdown15_5and10MinDurations() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val (config, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = false,
        )
        assertThat(config.allowBypassAfterCountdown).isTrue()
        assertThat(policy.countToday).isEqualTo(0)
        assertThat(policy.countdownSecondsOverride).isEqualTo(15)
        assertThat(policy.pauseAllowed).isFalse()
        assertThat(policy.durations).containsExactly(
            "5 min" to 5L * 60_000L,
            "10 min" to 10L * 60_000L,
        ).inOrder()
    }

    @Test
    fun nonStrict_countOne_countdown30() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        incrementCount(1)
        val (_, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = false,
        )
        assertThat(policy.countToday).isEqualTo(1)
        assertThat(policy.countdownSecondsOverride).isEqualTo(30)
        // Below threshold (<3): durations still 5/10 min.
        assertThat(policy.durations).containsExactly(
            "5 min" to 5L * 60_000L,
            "10 min" to 10L * 60_000L,
        ).inOrder()
    }

    @Test
    fun nonStrict_countTwo_countdown60() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        incrementCount(2)
        val (_, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = false,
        )
        assertThat(policy.countToday).isEqualTo(2)
        assertThat(policy.countdownSecondsOverride).isEqualTo(60)
        assertThat(policy.durations).containsExactly(
            "5 min" to 5L * 60_000L,
            "10 min" to 10L * 60_000L,
        ).inOrder()
    }

    @Test
    fun nonStrict_countThree_countdown120_shortDurations() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        incrementCount(3)
        val (_, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = false,
        )
        assertThat(policy.countToday).isEqualTo(3)
        assertThat(policy.countdownSecondsOverride).isEqualTo(120)
        assertThat(policy.durations).containsExactly(
            "1 min" to 1L * 60_000L,
            "2 min" to 2L * 60_000L,
        ).inOrder()
    }

    @Test
    fun nonStrict_countFive_clampsTo120AndShortDurations() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        incrementCount(5)
        val (_, policy) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = false,
        )
        assertThat(policy.countToday).isEqualTo(5)
        assertThat(policy.countdownSecondsOverride).isEqualTo(120)
        assertThat(policy.durations).containsExactly(
            "1 min" to 1L * 60_000L,
            "2 min" to 2L * 60_000L,
        ).inOrder()
    }

    @Test
    fun nonStrict_preservesBaseConfigBranding_setsBypassTrue() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val baseConfig = OverlayConfig(
            backgroundColorArgb = 0xFFAABBCC.toInt(),
            messageTitle = "Block!",
            allowBypassAfterCountdown = false, // will be overridden by non-strict
        )
        val (config, _) = OverlayPolicies.buildUsageLimitOverlay(
            ctx,
            pkg,
            isStrict = false,
            baseConfig = baseConfig,
        )
        assertThat(config.backgroundColorArgb).isEqualTo(0xFFAABBCC.toInt())
        assertThat(config.messageTitle).isEqualTo("Block!")
        // Non-strict ⇒ bypass allowed.
        assertThat(config.allowBypassAfterCountdown).isTrue()
    }
}
