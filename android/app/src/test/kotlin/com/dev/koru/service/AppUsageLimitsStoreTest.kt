package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
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
 * Tests for [AppUsageLimitsStore]:
 *  - data-class fields,
 *  - file roundtrip & filtering of zero-minute entries,
 *  - legacy and extended JSON parsing,
 *  - convenience helpers [AppUsageLimitsStore.limitMinutesFor] /
 *    [AppUsageLimitsStore.isStrictFor] / [AppUsageLimitsStore.entryFor],
 *  - cache invalidation after [AppUsageLimitsStore.save].
 *
 * The store uses a static `AtomicReference` cache: every test resets it via
 * reflection so the runs are independent.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AppUsageLimitsStoreTest {

    private val fileName = "koru_app_limits.json"

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
        // Reset the static AtomicReference<CachedSnapshot?> cache.
        val field = AppUsageLimitsStore::class.java.getDeclaredField("cache")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val cache = field.get(AppUsageLimitsStore) as AtomicReference<Any?>
        cache.set(null)
    }

    // -------- LimitEntry data class --------

    @Test
    fun limitEntry_fieldsAccessible() {
        val e = AppUsageLimitsStore.LimitEntry(minutes = 42, strict = false)
        assertThat(e.minutes).isEqualTo(42)
        assertThat(e.strict).isFalse()
    }

    // -------- save / read roundtrip --------

    @Test
    fun saveThenRead_singleEntry_roundtrip() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        AppUsageLimitsStore.save(
            ctx,
            mapOf("com.a" to AppUsageLimitsStore.LimitEntry(30, true)),
        )
        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read).containsExactly(
            "com.a",
            AppUsageLimitsStore.LimitEntry(30, true),
        )
    }

    @Test
    fun save_filtersZeroAndNegativeMinutes() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        AppUsageLimitsStore.save(
            ctx,
            mapOf(
                "com.a" to AppUsageLimitsStore.LimitEntry(0, true),
                "com.b" to AppUsageLimitsStore.LimitEntry(30, true),
                "com.c" to AppUsageLimitsStore.LimitEntry(-5, true),
            ),
        )
        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read.keys).containsExactly("com.b")
        assertThat(read["com.b"]).isEqualTo(AppUsageLimitsStore.LimitEntry(30, true))
    }

    @Test
    fun read_missingFile_returnsEmptyMap() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(AppUsageLimitsStore.read(ctx)).isEmpty()
    }

    // -------- Legacy format --------

    @Test
    fun read_legacyIntFormat_treatedAsStrict() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("""{"com.x": 30}""")
        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read).containsExactly(
            "com.x",
            AppUsageLimitsStore.LimitEntry(30, true),
        )
    }

    // -------- Extended format --------

    @Test
    fun read_extendedFormat_withExplicitStrict() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText(
            """{"com.x": {"minutes":45,"strict":false}}""",
        )
        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read).containsExactly(
            "com.x",
            AppUsageLimitsStore.LimitEntry(45, false),
        )
    }

    @Test
    fun read_extendedFormat_missingStrict_defaultsToTrue() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("""{"com.x": {"minutes":30}}""")
        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read).containsExactly(
            "com.x",
            AppUsageLimitsStore.LimitEntry(30, true),
        )
    }

    @Test
    fun read_extendedFormat_zeroMinutes_filteredOut() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText(
            """{"com.x": {"minutes":0,"strict":true}, "com.y": {"minutes":15,"strict":true}}""",
        )
        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read.keys).containsExactly("com.y")
    }

    // -------- Helpers --------

    @Test
    fun limitMinutesFor_returnsValue_orZeroIfMissing() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        AppUsageLimitsStore.save(
            ctx,
            mapOf("com.a" to AppUsageLimitsStore.LimitEntry(20, true)),
        )
        assertThat(AppUsageLimitsStore.limitMinutesFor(ctx, "com.a")).isEqualTo(20)
        assertThat(AppUsageLimitsStore.limitMinutesFor(ctx, "com.missing")).isEqualTo(0)
    }

    @Test
    fun isStrictFor_returnsSavedFlag_orTrueIfMissing() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        AppUsageLimitsStore.save(
            ctx,
            mapOf(
                "com.strict" to AppUsageLimitsStore.LimitEntry(20, true),
                "com.soft" to AppUsageLimitsStore.LimitEntry(20, false),
            ),
        )
        assertThat(AppUsageLimitsStore.isStrictFor(ctx, "com.strict")).isTrue()
        assertThat(AppUsageLimitsStore.isStrictFor(ctx, "com.soft")).isFalse()
        // Default conservative: strict=true when entry absent.
        assertThat(AppUsageLimitsStore.isStrictFor(ctx, "com.missing")).isTrue()
    }

    @Test
    fun entryFor_returnsEntryOrNull() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        AppUsageLimitsStore.save(
            ctx,
            mapOf("com.a" to AppUsageLimitsStore.LimitEntry(10, false)),
        )
        assertThat(AppUsageLimitsStore.entryFor(ctx, "com.a"))
            .isEqualTo(AppUsageLimitsStore.LimitEntry(10, false))
        assertThat(AppUsageLimitsStore.entryFor(ctx, "com.missing")).isNull()
    }

    // -------- Cache --------

    @Test
    fun save_populatesCache_immediately() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        AppUsageLimitsStore.save(
            ctx,
            mapOf("com.a" to AppUsageLimitsStore.LimitEntry(30, true)),
        )

        // Inspect the static cache via reflection: it must be populated after
        // the save without us calling read() first. The CachedSnapshot is a
        // private nested class, so we walk its fields.
        val cacheField = AppUsageLimitsStore::class.java.getDeclaredField("cache")
        cacheField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val cache = cacheField.get(AppUsageLimitsStore) as AtomicReference<Any?>
        val snapshot = cache.get()
        assertThat(snapshot).isNotNull()

        // Pull `data` map out of the snapshot to confirm content.
        val dataField = snapshot!!.javaClass.getDeclaredField("data")
        dataField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val data = dataField.get(snapshot) as Map<String, AppUsageLimitsStore.LimitEntry>
        assertThat(data).containsExactly(
            "com.a",
            AppUsageLimitsStore.LimitEntry(30, true),
        )
    }

    @Test
    fun save_thenRead_returnsImmediateValueWithoutReparsingFileFromOldCache() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // First save: cache is now {com.a -> 10}.
        AppUsageLimitsStore.save(
            ctx,
            mapOf("com.a" to AppUsageLimitsStore.LimitEntry(10, true)),
        )
        // Second save with different content: cache must be updated, not
        // returning the previous snapshot.
        AppUsageLimitsStore.save(
            ctx,
            mapOf("com.b" to AppUsageLimitsStore.LimitEntry(99, false)),
        )

        val read = AppUsageLimitsStore.read(ctx)
        assertThat(read).containsExactly(
            "com.b",
            AppUsageLimitsStore.LimitEntry(99, false),
        )
    }
}
