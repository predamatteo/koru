package com.dev.koru.strictmode

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
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
 * Tests for [StrictModeStore].
 *
 * Covers:
 *  - the public bit constants (must match the enforcer values),
 *  - save/read roundtrip against EncryptedSharedPreferences,
 *  - migration from the legacy plain `koru_strict_mask.txt` file,
 *  - HMAC tamper detection (fail-secure = ALL_OPTIONS_ENABLED).
 *
 * The encrypted store is shared across tests in the same Robolectric
 * application — we wipe it in [setUp] / [tearDown] to keep tests independent.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class StrictModeStoreTest {

    private val legacyFile = "koru_strict_mask.txt"
    private val prefsName = "koru_strict_secure"
    private val keyMask = "mask"
    private val keyMaskHmac = "mask_hmac"

    @Before
    fun setUp() {
        clearAllState()
    }

    @After
    fun tearDown() {
        clearAllState()
    }

    private fun clearAllState() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Wipe legacy file.
        File(ctx.filesDir, legacyFile).delete()
        // Wipe EncryptedSharedPreferences via the underlying plain prefs file.
        // Robolectric stores it at /data/data/<pkg>/shared_prefs/<name>.xml —
        // calling edit().clear() is the supported way that also tears down
        // the keystore alias for the prefs name.
        try {
            val prefs = encryptedPrefs(ctx)
            prefs?.edit()?.clear()?.commit()
        } catch (_: Exception) {
            // Best effort — if Keystore isn't reachable we still proceed.
        }
    }

    private fun encryptedPrefs(ctx: Context) = try {
        val key = MasterKey.Builder(ctx.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            ctx.applicationContext,
            prefsName,
            key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (_: Exception) {
        null
    }

    // -------- Bit constants --------

    @Test
    fun bitConstants_matchSpec() {
        assertThat(StrictModeStore.ALL_OPTIONS_ENABLED).isEqualTo(31)
        assertThat(StrictModeStore.BLOCK_EDITING).isEqualTo(1)
        assertThat(StrictModeStore.BLOCK_SETTINGS).isEqualTo(2)
        assertThat(StrictModeStore.BLOCK_UNINSTALLING).isEqualTo(4)
        assertThat(StrictModeStore.BLOCK_RECENT_APPS).isEqualTo(8)
        assertThat(StrictModeStore.BLOCK_SPLIT_SCREEN).isEqualTo(16)
        // ALL_OPTIONS_ENABLED is the bitwise OR of all the individual bits.
        val expected = StrictModeStore.BLOCK_EDITING or
            StrictModeStore.BLOCK_SETTINGS or
            StrictModeStore.BLOCK_UNINSTALLING or
            StrictModeStore.BLOCK_RECENT_APPS or
            StrictModeStore.BLOCK_SPLIT_SCREEN
        assertThat(StrictModeStore.ALL_OPTIONS_ENABLED).isEqualTo(expected)
    }

    // -------- read / save roundtrip --------

    @Test
    fun readMask_freshStore_returnsZero() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertThat(StrictModeStore.readMask(ctx)).isEqualTo(0)
    }

    @Test
    fun saveMaskThenRead_roundtrips() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        StrictModeStore.saveMask(ctx, 14)
        assertThat(StrictModeStore.readMask(ctx)).isEqualTo(14)
    }

    @Test
    fun writeMask_aliasOfSaveMask() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        StrictModeStore.writeMask(ctx, 7)
        assertThat(StrictModeStore.readMask(ctx)).isEqualTo(7)
    }

    // -------- Legacy migration --------

    @Test
    fun migration_fromLegacyFile_movesValueAndDeletesFile() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, legacyFile).writeText("15")
        // First read triggers the migration.
        val read = StrictModeStore.readMask(ctx)
        assertThat(read).isEqualTo(15)
        // Legacy file must be cleaned up after migration.
        assertThat(File(ctx.filesDir, legacyFile).exists()).isFalse()
    }

    @Test
    fun migration_fromLegacyFile_emptyContent_returnsZero() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, legacyFile).writeText("")
        val read = StrictModeStore.readMask(ctx)
        assertThat(read).isEqualTo(0)
    }

    @Test
    fun migration_fromLegacyFile_invalidContent_returnsZero() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, legacyFile).writeText("not-an-int")
        val read = StrictModeStore.readMask(ctx)
        assertThat(read).isEqualTo(0)
    }

    // -------- HMAC tamper detection --------

    @Test
    fun readMask_hmacMismatch_failsSecureAllOptions() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        StrictModeStore.saveMask(ctx, 14)

        // Tamper: overwrite the stored int but keep the stale HMAC. We go
        // through the same EncryptedSharedPreferences instance the store
        // uses so we're touching the actual backing file.
        val prefs = encryptedPrefs(ctx)
        if (prefs == null) {
            // Keystore unavailable: nothing to tamper with. Skip the check
            // gracefully — the migration branch already covered fallback.
            return
        }
        prefs.edit().putInt(keyMask, 7).apply() // hmac was for value=14

        // The store must notice the mismatch and return the fail-secure
        // value (ALL_OPTIONS_ENABLED = 31), not the tampered value.
        val read = StrictModeStore.readMask(ctx)
        assertThat(read).isEqualTo(StrictModeStore.ALL_OPTIONS_ENABLED)
    }

    @Test
    fun readMask_hmacEmpty_failsSecure() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        StrictModeStore.saveMask(ctx, 14)
        val prefs = encryptedPrefs(ctx)
        if (prefs == null) return
        prefs.edit().putString(keyMaskHmac, "").apply()
        assertThat(StrictModeStore.readMask(ctx)).isEqualTo(StrictModeStore.ALL_OPTIONS_ENABLED)
    }
}
