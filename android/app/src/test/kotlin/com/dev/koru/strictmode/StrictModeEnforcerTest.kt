package com.dev.koru.strictmode

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Tests for [StrictModeEnforcer].
 *
 * The enforcer's main entry point — `handleEvent(AccessibilityService, AccessibilityEvent)`
 * — needs a real AccessibilityService binder to call `performGlobalAction` and
 * its private-companion package-level mutator
 * `KoruAccessibilityService.performGoHomeForBlock`. Both are device-only:
 * Robolectric can fake the service stub, but the global action plumbs into
 * the WindowManager binder and the per-process flag mutation in
 * `:accessibility` is undefined off-device.
 *
 * Here we cover the public bit constants (they must match the values in
 * [StrictModeStore]) and the `invalidateCache` no-throw contract.
 */
class StrictModeEnforcerTest {

    // -------- Bit constants --------

    @Test
    fun bitConstants_matchStoreSpec() {
        assertThat(StrictModeEnforcer.BLOCK_EDITING).isEqualTo(1)
        assertThat(StrictModeEnforcer.BLOCK_SETTINGS).isEqualTo(2)
        assertThat(StrictModeEnforcer.BLOCK_UNINSTALLING).isEqualTo(4)
        assertThat(StrictModeEnforcer.BLOCK_RECENT_APPS).isEqualTo(8)
        assertThat(StrictModeEnforcer.BLOCK_SPLIT_SCREEN).isEqualTo(16)
    }

    @Test
    fun bitConstants_matchStoreAliases() {
        assertThat(StrictModeEnforcer.BLOCK_EDITING).isEqualTo(StrictModeStore.BLOCK_EDITING)
        assertThat(StrictModeEnforcer.BLOCK_SETTINGS).isEqualTo(StrictModeStore.BLOCK_SETTINGS)
        assertThat(StrictModeEnforcer.BLOCK_UNINSTALLING).isEqualTo(StrictModeStore.BLOCK_UNINSTALLING)
        assertThat(StrictModeEnforcer.BLOCK_RECENT_APPS).isEqualTo(StrictModeStore.BLOCK_RECENT_APPS)
        assertThat(StrictModeEnforcer.BLOCK_SPLIT_SCREEN).isEqualTo(StrictModeStore.BLOCK_SPLIT_SCREEN)
    }

    // -------- invalidateCache --------

    @Test
    fun invalidateCache_doesNotThrow() {
        // Idempotent + safe to call before any read: should never throw.
        StrictModeEnforcer.invalidateCache()
        StrictModeEnforcer.invalidateCache()
    }

    // -------- Cache fields reset via reflection --------

    @Test
    fun invalidateCache_resetsInternalState() {
        val cls = StrictModeEnforcer::class.java
        val cached = cls.getDeclaredField("cachedMask").apply { isAccessible = true }
        val lastRead = cls.getDeclaredField("lastReadTime").apply { isAccessible = true }

        // Bypass invalidate explicitly to assert default invariants:
        StrictModeEnforcer.invalidateCache()
        assertThat(cached.getInt(StrictModeEnforcer)).isEqualTo(-1)
        assertThat(lastRead.getLong(StrictModeEnforcer)).isEqualTo(0L)
    }
}
