package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [BypassCountStore].
 *
 * Covers the basic counter API ([BypassCountStore.todayCount],
 * [BypassCountStore.increment], [BypassCountStore.reset]) plus the
 * date-tracking fallback behaviour: when the saved date does not match
 * "today" the count goes back to 0 without rewriting the file.
 *
 * ARCH-03/CR-04: lo store delega a un [FileBackedStore]; la cache di processo è
 * azzerata tra i test via il test hook `invalidateCacheForTest()`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class BypassCountStoreTest {

    private val fileName = "koru_bypass_counts.json"

    @Before
    fun setUp() {
        clearFileAndCache()
    }

    @After
    fun tearDown() {
        clearFileAndCache()
    }

    private fun clearFileAndCache() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).delete()
        File(ctx.filesDir, "$fileName.tmp").delete()
        File(ctx.filesDir, "$fileName.lock").delete()
        // ARCH-03/CR-04: la cache vive ora dentro il FileBackedStore interno; il
        // test hook la azzera senza reflection sulla struttura privata.
        BypassCountStore.invalidateCacheForTest()
    }

    // -------- todayCount baseline --------

    @Test
    fun todayCount_emptyFile_returnsZero() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(0)
    }

    // -------- increment --------

    @Test
    fun increment_firstCall_returnsOne() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val n = BypassCountStore.increment(ctx, "com.x")
        assertThat(n).isEqualTo(1)
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(1)
    }

    @Test
    fun increment_threeTimes_returnsThree() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        BypassCountStore.increment(ctx, "com.x")
        BypassCountStore.increment(ctx, "com.x")
        val n = BypassCountStore.increment(ctx, "com.x")
        assertThat(n).isEqualTo(3)
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(3)
    }

    @Test
    fun increment_differentPackages_independentCounters() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        BypassCountStore.increment(ctx, "com.a")
        BypassCountStore.increment(ctx, "com.a")
        BypassCountStore.increment(ctx, "com.b")
        assertThat(BypassCountStore.todayCount(ctx, "com.a")).isEqualTo(2)
        assertThat(BypassCountStore.todayCount(ctx, "com.b")).isEqualTo(1)
    }

    // -------- reset --------

    @Test
    fun reset_clearsCounter() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        BypassCountStore.increment(ctx, "com.x")
        BypassCountStore.increment(ctx, "com.x")
        BypassCountStore.reset(ctx, "com.x")
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(0)
    }

    @Test
    fun reset_doesNotAffectOtherPackages() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        BypassCountStore.increment(ctx, "com.a")
        BypassCountStore.increment(ctx, "com.b")
        BypassCountStore.reset(ctx, "com.a")
        assertThat(BypassCountStore.todayCount(ctx, "com.a")).isEqualTo(0)
        assertThat(BypassCountStore.todayCount(ctx, "com.b")).isEqualTo(1)
    }

    // -------- Persistence across cache resets --------

    @Test
    fun increment_persistsAcrossCacheReset() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        BypassCountStore.increment(ctx, "com.x")
        BypassCountStore.increment(ctx, "com.x")
        // Simulate a new process / fresh JVM by clearing the cache only.
        BypassCountStore.invalidateCacheForTest()

        // Count should be re-loaded from the JSON file on disk.
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(2)
    }

    // -------- Old-date entries --------

    @Test
    fun todayCount_savedDateIsOld_returnsZero() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Write a JSON file with an entry dated 2020-01-01 — never "today".
        File(ctx.filesDir, fileName).writeText(
            """{"com.x":{"date":"2020-01-01","count":5}}""",
        )
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(0)
    }

    // -------- Corrupted file fallback --------

    @Test
    fun todayCount_corruptedFile_returnsZero() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("{not json")
        assertThat(BypassCountStore.todayCount(ctx, "com.x")).isEqualTo(0)
    }
}
