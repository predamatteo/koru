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
 * Tests for [UiSettingsStore] — lo store cross-process del font scelto in-app.
 *
 * Verifica il round-trip write→read, l'overwrite, la persistenza attraverso un
 * reset di cache (simula il processo `:accessibility` con cache fredda) e il
 * fallback fail-safe a System su file corrotto/assente. Stesso pattern di
 * [BypassCountStoreTest] (ARCH-03): cache di processo azzerata via test hook.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class UiSettingsStoreTest {

    private val fileName = "koru_ui_settings.json"

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
        UiSettingsStore.invalidateCacheForTest()
    }

    @Test
    fun activeFontId_emptyFile_returnsSystemDefault() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(UiSettingsStore.DEFAULT_FONT_ID).isEqualTo(0)
        assertThat(UiSettingsStore.activeFontId(ctx))
            .isEqualTo(UiSettingsStore.DEFAULT_FONT_ID)
    }

    @Test
    fun setActiveFontId_thenRead_roundTrips() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(UiSettingsStore.setActiveFontId(ctx, 2)).isTrue()
        assertThat(UiSettingsStore.activeFontId(ctx)).isEqualTo(2)
    }

    @Test
    fun setActiveFontId_overwritesPreviousValue() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        UiSettingsStore.setActiveFontId(ctx, 1)
        UiSettingsStore.setActiveFontId(ctx, 4)
        assertThat(UiSettingsStore.activeFontId(ctx)).isEqualTo(4)
    }

    @Test
    fun activeFontId_persistsAcrossCacheReset() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        UiSettingsStore.setActiveFontId(ctx, 3)
        // Simula un secondo processo (es. :accessibility) con cache fredda:
        // il valore deve essere riletto dal file su disco.
        UiSettingsStore.invalidateCacheForTest()
        assertThat(UiSettingsStore.activeFontId(ctx)).isEqualTo(3)
    }

    @Test
    fun activeFontId_corruptedFile_returnsSystemDefault() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("{not json")
        UiSettingsStore.invalidateCacheForTest()
        assertThat(UiSettingsStore.activeFontId(ctx))
            .isEqualTo(UiSettingsStore.DEFAULT_FONT_ID)
    }

    // -------- contatore di reel --------

    @Test
    fun reelCounter_emptyFile_isEnabledByDefault() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(UiSettingsStore.isReelCounterEnabled(ctx)).isTrue()
    }

    @Test
    fun setReelCounterEnabled_roundTrips() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(UiSettingsStore.setReelCounterEnabled(ctx, false)).isTrue()
        assertThat(UiSettingsStore.isReelCounterEnabled(ctx)).isFalse()
        UiSettingsStore.invalidateCacheForTest()
        assertThat(UiSettingsStore.isReelCounterEnabled(ctx)).isFalse()
    }

    @Test
    fun legacyFileWithoutTheKey_readsAsEnabled() {
        // File scritto da una versione precedente: la chiave non esiste. Deve
        // leggersi come "acceso", non come `false` implicito — un update
        // dell'app non deve spegnere la feature di soppiatto.
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("""{"activeFontId":3}""")
        UiSettingsStore.invalidateCacheForTest()
        assertThat(UiSettingsStore.isReelCounterEnabled(ctx)).isTrue()
        assertThat(UiSettingsStore.activeFontId(ctx)).isEqualTo(3)
    }

    @Test
    fun theTwoSettingsDoNotOverwriteEachOther() {
        // Regressione: con una `write` incondizionata al posto di una
        // read-modify-write, salvare il font azzerava il flag del contatore
        // (e viceversa), perché ogni scrittura rigenerava il file intero dai
        // soli valori noti al chiamante.
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        UiSettingsStore.setReelCounterEnabled(ctx, false)
        UiSettingsStore.setActiveFontId(ctx, 4)
        assertThat(UiSettingsStore.isReelCounterEnabled(ctx)).isFalse()
        assertThat(UiSettingsStore.activeFontId(ctx)).isEqualTo(4)

        UiSettingsStore.setReelCounterEnabled(ctx, true)
        assertThat(UiSettingsStore.activeFontId(ctx)).isEqualTo(4)
    }

    @Test
    fun reelCounter_corruptedFile_fallsBackToEnabled() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("{not json")
        UiSettingsStore.invalidateCacheForTest()
        assertThat(UiSettingsStore.isReelCounterEnabled(ctx)).isTrue()
    }
}
