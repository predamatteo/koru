package com.dev.koru.notification

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
 * Tests for [NotificationFilterStore]:
 *  - read/save roundtrip,
 *  - empty-set semantics,
 *  - [NotificationFilterStore.isSilenced] membership,
 *  - graceful fallback on corrupted / malformed JSON.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class NotificationFilterStoreTest {

    private val fileName = "koru_notification_filters.json"

    @Before
    fun setUp() {
        deleteFile()
    }

    @After
    fun tearDown() {
        deleteFile()
    }

    private fun deleteFile() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).delete()
    }

    // -------- read empty / missing --------

    @Test
    fun read_missingFile_returnsEmptySet() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(NotificationFilterStore.read(ctx)).isEmpty()
    }

    // -------- save / read roundtrip --------

    @Test
    fun saveThenRead_roundtripExact() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val expected = setOf("com.a", "com.b", "com.c")
        NotificationFilterStore.save(ctx, expected)
        val read = NotificationFilterStore.read(ctx)
        assertThat(read).isEqualTo(expected)
    }

    @Test
    fun saveEmptySet_thenRead_returnsEmpty() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        NotificationFilterStore.save(ctx, emptySet())
        assertThat(NotificationFilterStore.read(ctx)).isEmpty()
    }

    // -------- isSilenced --------

    @Test
    fun isSilenced_returnsTrueForMember() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        NotificationFilterStore.save(ctx, setOf("com.a", "com.b"))
        assertThat(NotificationFilterStore.isSilenced(ctx, "com.a")).isTrue()
        assertThat(NotificationFilterStore.isSilenced(ctx, "com.b")).isTrue()
    }

    @Test
    fun isSilenced_returnsFalseForNonMember() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        NotificationFilterStore.save(ctx, setOf("com.a"))
        assertThat(NotificationFilterStore.isSilenced(ctx, "com.zzz")).isFalse()
    }

    @Test
    fun isSilenced_returnsFalseWhenStoreEmpty() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(NotificationFilterStore.isSilenced(ctx, "com.x")).isFalse()
    }

    // -------- Fallback paths --------

    @Test
    fun read_corruptedJson_returnsEmptySet() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("{not json")
        assertThat(NotificationFilterStore.read(ctx)).isEmpty()
    }

    @Test
    fun read_arrayOfNonStrings_gracefulFallback() {
        // The reader expects an array of strings — when the underlying
        // entries are not strings, [JSONArray.getString] throws and the
        // catch-all returns empty.
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("[123]")
        // JSON int 123 → getString returns "123" actually (JSONArray
        // coerces). We assert the membership of the coerced string instead
        // of a specific failure, so the test stays accurate regardless of
        // org.json coercion semantics on the host.
        val result = NotificationFilterStore.read(ctx)
        // Either empty (strict reading) or {"123"} (coerced reading) is
        // acceptable: the public contract is "never throw and never return
        // garbage". The behaviour must be one of these two.
        assertThat(result.size).isAtMost(1)
        if (result.isNotEmpty()) {
            assertThat(result).containsExactly("123")
        }
    }

    @Test
    fun read_emptyArray_returnsEmptySet() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("[]")
        assertThat(NotificationFilterStore.read(ctx)).isEmpty()
    }
}
