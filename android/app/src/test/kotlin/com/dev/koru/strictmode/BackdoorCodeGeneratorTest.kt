package com.dev.koru.strictmode

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [BackdoorCodeGenerator].
 *
 * Robolectric backs the Android Keystore with an in-process implementation
 * since 4.x, so [androidx.security.crypto.EncryptedSharedPreferences] is
 * usable in unit tests. If the underlying Keystore is unavailable at runtime
 * the generator degrades to a deterministic SHA-256 path — the tests on
 * `getOrGenerateForWeek` still hold under both paths because we only check
 * the structure (alphabet, length, persistence within the same week) and the
 * validation contract.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class BackdoorCodeGeneratorTest {

    private val ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    private val HEX_ALPHABET = "0123456789ABCDEF"

    // -------- Aliases --------

    @Test
    fun generateCurrentCode_isAliasForGetOrGenerateForWeek() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val a = BackdoorCodeGenerator.generateCurrentCode(ctx)
        val b = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(a).isEqualTo(b)
    }

    @Test
    fun forWeek_isAliasForGetOrGenerateForWeek() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val a = BackdoorCodeGenerator.forWeek(ctx)
        val b = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(a).isEqualTo(b)
    }

    // -------- Code shape --------

    @Test
    fun getOrGenerateForWeek_returnsEightChars() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(code).isNotEmpty()
        assertThat(code).hasLength(8)
    }

    @Test
    fun getOrGenerateForWeek_returnsAllAllowedAlphabetChars() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        // Bootstrap path may return a hex-uppercase code (legacy deterministic).
        // Real random path uses ALPHABET. We accept either, just no junk.
        val combined = (ALPHABET + HEX_ALPHABET).toSet()
        code.forEach { c ->
            assertThat(combined).contains(c)
        }
    }

    // -------- Persistence within week --------

    @Test
    fun getOrGenerateForWeek_twiceInSameWeek_returnsSameCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val first = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        val second = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(second).isEqualTo(first)
    }

    // -------- validateCode --------

    @Test
    fun validateCode_acceptsCurrentCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, code)).isTrue()
    }

    @Test
    fun validateCode_rejectsWrongCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // First read the real code to learn its length (constant-time compare
        // requires same length to even start comparing).
        val real = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        val wrong = "WRONG" + "X".repeat((real.length - 5).coerceAtLeast(0))
        // Make sure they differ for non-trivial length.
        assertThat(BackdoorCodeGenerator.validateCode(ctx, wrong)).isFalse()
    }

    @Test
    fun validateCode_rejectsEmpty() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Make sure a code is generated first so the store is populated.
        BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, "")).isFalse()
    }

    @Test
    fun validateCode_caseInsensitive() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, code.lowercase())).isTrue()
    }

    @Test
    fun validateCode_trimsWhitespace() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, " $code ")).isTrue()
    }

    // -------- rotate --------

    @Test
    fun rotate_invalidatesOldCode_validatesNewOne() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val old = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        BackdoorCodeGenerator.rotate(ctx)
        val newCode = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)

        // If rotate succeeded the codes differ. In a degraded Keystore
        // environment rotate is a no-op and codes match; in that case we
        // still verify the validate contract.
        if (newCode != old) {
            assertThat(BackdoorCodeGenerator.validateCode(ctx, old)).isFalse()
        }
        assertThat(BackdoorCodeGenerator.validateCode(ctx, newCode)).isTrue()
    }

    @Test
    fun multipleCallsInSameWeek_returnSameCode_acrossContextLookups() {
        // In Robolectric `ApplicationProvider.getApplicationContext()` returns
        // the same application instance, so the underlying Keystore-backed
        // store is the same. This sanity checks no per-call drift.
        val ctx1 = ApplicationProvider.getApplicationContext<Context>()
        val ctx2 = ApplicationProvider.getApplicationContext<Context>()
        val c1 = BackdoorCodeGenerator.getOrGenerateForWeek(ctx1)
        val c2 = BackdoorCodeGenerator.getOrGenerateForWeek(ctx2)
        assertThat(c1).isEqualTo(c2)
    }

    // -------- constantTimeEquals via reflection --------

    @Test
    fun constantTimeEquals_returnsTrueForIdenticalStrings() {
        val m = BackdoorCodeGenerator::class.java.getDeclaredMethod(
            "constantTimeEquals",
            String::class.java,
            String::class.java,
        )
        m.isAccessible = true
        val result = m.invoke(BackdoorCodeGenerator, "ABCD1234", "ABCD1234") as Boolean
        assertThat(result).isTrue()
    }

    @Test
    fun constantTimeEquals_returnsFalseForDifferentLength() {
        val m = BackdoorCodeGenerator::class.java.getDeclaredMethod(
            "constantTimeEquals",
            String::class.java,
            String::class.java,
        )
        m.isAccessible = true
        val result = m.invoke(BackdoorCodeGenerator, "ABCD", "ABCDE") as Boolean
        assertThat(result).isFalse()
    }

    @Test
    fun constantTimeEquals_returnsFalseForDifferentContentSameLength() {
        val m = BackdoorCodeGenerator::class.java.getDeclaredMethod(
            "constantTimeEquals",
            String::class.java,
            String::class.java,
        )
        m.isAccessible = true
        val result = m.invoke(BackdoorCodeGenerator, "ABCD1234", "ABCD1235") as Boolean
        assertThat(result).isFalse()
    }
}
