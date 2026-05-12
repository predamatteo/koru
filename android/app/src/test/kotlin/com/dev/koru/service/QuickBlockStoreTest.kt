package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [QuickBlockStore]:
 *  - the IDLE snapshot constants,
 *  - the [QuickBlockStore.Snapshot.shouldBlock] decision matrix,
 *  - file roundtrip via [QuickBlockStore.save] / [QuickBlockStore.read],
 *  - fallback to IDLE on missing or corrupted file,
 *  - [QuickBlockStore.clear] semantics.
 *
 * Robolectric is required: the store writes to `context.filesDir`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class QuickBlockStoreTest {

    private val fileName = "koru_quick_block_state.json"

    @After
    fun tearDown() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).delete()
    }

    // -------- Snapshot.IDLE --------

    @Test
    fun idleSnapshot_hasExpectedDefaults() {
        val idle = QuickBlockStore.Snapshot.IDLE
        assertThat(idle.isActive).isFalse()
        assertThat(idle.isPomodoroMode).isFalse()
        assertThat(idle.isBreakPhase).isFalse()
        assertThat(idle.expiresAt).isEqualTo(0L)
        assertThat(idle.whitelist).isEmpty()
    }

    // -------- Snapshot.shouldBlock --------

    @Test
    fun shouldBlock_idleSnapshot_returnsFalse() {
        val snap = QuickBlockStore.Snapshot.IDLE
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_activeFutureExpiry_pkgNotWhitelisted_returnsTrue() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed"),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isTrue()
    }

    @Test
    fun shouldBlock_activeFutureExpiry_pkgWhitelisted_returnsFalse() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed", "com.x"),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_activeExpired_returnsFalse() {
        // expiresAt <= now ⇒ "in 1..now" path: expired safety valve
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 500L,
            whitelist = emptySet(),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_pomodoroBreakPhase_returnsFalse() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = true,
            expiresAt = 10_000L,
            whitelist = emptySet(),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_pomodoroWorkPhase_pkgNotWhitelisted_returnsTrue() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed"),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isTrue()
    }

    @Test
    fun shouldBlock_expiresAtZero_returnsTrue() {
        // expiresAt = 0 ⇒ NOT in 1..now ⇒ blocking remains active (no expiry).
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 0L,
            whitelist = emptySet(),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isTrue()
    }

    // -------- save / read roundtrip --------

    @Test
    fun saveThenRead_exactRoundtrip_withWhitelist() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val original = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = false,
            expiresAt = 1_700_000_000_000L,
            whitelist = setOf("com.a", "com.b", "com.c"),
        )
        QuickBlockStore.save(ctx, original)
        val readBack = QuickBlockStore.read(ctx)

        assertThat(readBack.isActive).isTrue()
        assertThat(readBack.isPomodoroMode).isTrue()
        assertThat(readBack.isBreakPhase).isFalse()
        assertThat(readBack.expiresAt).isEqualTo(1_700_000_000_000L)
        assertThat(readBack.whitelist).containsExactly("com.a", "com.b", "com.c")
    }

    @Test
    fun saveIdle_thenRead_returnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        QuickBlockStore.save(ctx, QuickBlockStore.Snapshot.IDLE)
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }

    // -------- Fallback paths --------

    @Test
    fun read_corruptedFile_returnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("{not json")
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }

    @Test
    fun read_missingFile_returnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Ensure file missing
        File(ctx.filesDir, fileName).delete()
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }

    // -------- clear --------

    @Test
    fun clear_writesIdle_andNextReadReturnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        QuickBlockStore.save(
            ctx,
            QuickBlockStore.Snapshot(
                isActive = true,
                isPomodoroMode = false,
                isBreakPhase = false,
                expiresAt = 9999L,
                whitelist = setOf("com.x"),
            ),
        )
        QuickBlockStore.clear(ctx)
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }
}
