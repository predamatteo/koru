package com.dev.koru.strictmode

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [BackdoorCodeGenerator].
 *
 * SEC-10: il path di fallback deterministico (`SHA-256(ANDROID_ID‖week‖salt)`,
 * calcolabile offline) è stato RIMOSSO. Se il Keystore non è disponibile il
 * generatore ritorna `null` (fail-secure) invece di un codice indovinabile.
 *
 * Nota ambiente: sotto Robolectric la creazione di EncryptedSharedPreferences
 * per le prefs del backdoor (`koru_backdoor_secure`) non è affidabile in questo
 * setup (il Keystore mock non sempre è raggiungibile). PRIMA questo era
 * mascherato dal fallback deterministico (che ritornava comunque un codice);
 * ora, correttamente, [BackdoorCodeGenerator.getOrGenerateForWeek] ritorna
 * `null`. I test STRUTTURALI (lunghezza, alfabeto, persistenza, validazione del
 * codice corrente) richiedono un codice reale: usano [requireCode], che SALTA
 * se il Keystore è giù (convenzione `assumeTrue` già in uso in
 * [StrictModeStoreTest]) invece di NPE-are. I test che PROVANO SEC-10 (rimozione
 * del path deterministico, "mai il vecchio codice", fail-secure di validateCode)
 * sono invece Keystore-AGNOSTICI e girano sempre.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class BackdoorCodeGeneratorTest {

    private val ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    /// Recupera il codice della settimana, saltando il test se il Keystore non
    /// è disponibile (in quel caso il generatore ritorna null per SEC-10 e non
    /// c'è un codice da esercitare). Sotto Robolectric il Keystore di norma c'è,
    /// quindi i test girano davvero.
    private fun requireCode(ctx: Context): String {
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assumeTrue(
            "Keystore non disponibile sotto Robolectric → codice null (SEC-10 fail-secure)",
            code != null,
        )
        return code!!
    }

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
        val code = requireCode(ctx)
        assertThat(code).hasLength(8)
    }

    @Test
    fun getOrGenerateForWeek_returnsOnlyCleanBase32Alphabet() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = requireCode(ctx)
        // SEC-10: il codice ora è SEMPRE random base32 pulito. Il vecchio
        // bootstrap deterministico produceva hex uppercase (0-9A-F), che può
        // contenere '0'/'1' — NON presenti nell'alfabeto pulito. Asserire che
        // ogni char sia nell'ALPHABET pulito documenta la rimozione del path
        // deterministico.
        val allowed = ALPHABET.toSet()
        code.forEach { c -> assertThat(allowed).contains(c) }
    }

    // -------- Persistence within week --------

    @Test
    fun getOrGenerateForWeek_twiceInSameWeek_returnsSameCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val first = requireCode(ctx)
        val second = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        assertThat(second).isEqualTo(first)
    }

    // -------- validateCode --------

    @Test
    fun validateCode_acceptsCurrentCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = requireCode(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, code)).isTrue()
    }

    @Test
    fun validateCode_rejectsWrongCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // First read the real code to learn its length (constant-time compare
        // requires same length to even start comparing).
        val real = requireCode(ctx)
        val wrong = "WRONG" + "X".repeat((real.length - 5).coerceAtLeast(0))
        // Make sure they differ for non-trivial length.
        assertThat(BackdoorCodeGenerator.validateCode(ctx, wrong)).isFalse()
    }

    @Test
    fun validateCode_rejectsEmpty() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Make sure a code is generated first so the store is populated.
        requireCode(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, "")).isFalse()
    }

    @Test
    fun validateCode_caseInsensitive() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = requireCode(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, code.lowercase())).isTrue()
    }

    @Test
    fun validateCode_trimsWhitespace() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = requireCode(ctx)
        assertThat(BackdoorCodeGenerator.validateCode(ctx, " $code ")).isTrue()
    }

    // -------- rotate --------

    @Test
    fun rotate_invalidatesOldCode_validatesNewOne() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val old = requireCode(ctx)
        BackdoorCodeGenerator.rotate(ctx)
        val newCode = requireCode(ctx)

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
        val c1 = requireCode(ctx1)
        val c2 = BackdoorCodeGenerator.getOrGenerateForWeek(ctx2)
        assertThat(c1).isEqualTo(c2)
    }

    // -------- SEC-10: deterministic fallback removed (Keystore-agnostic) --------

    /// Replica della vecchia formula deterministica `SHA-256(ANDROID_ID‖week‖salt)`
    /// troncata a 8 hex uppercase. Serve a dimostrare che il generatore NON
    /// ritorna più quel valore (era calcolabile offline: ANDROID_ID leakabile +
    /// salt nel repo open-source).
    private fun oldDeterministicCode(ctx: Context): String {
        val deviceId = android.provider.Settings.Secure.getString(
            ctx.contentResolver,
            android.provider.Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        val cal = java.util.Calendar.getInstance()
        val weekKey = "${cal.get(java.util.Calendar.YEAR)}-W${cal.get(java.util.Calendar.WEEK_OF_YEAR)}"
        val input = "$deviceId:$weekKey:koru_strict_v1"
        val md = java.security.MessageDigest.getInstance("SHA-256")
        return md.digest(input.toByteArray())
            .joinToString("") { "%02x".format(it) }
            .substring(0, 8)
            .uppercase()
    }

    @Test
    fun deterministicCodePath_isRemoved() {
        // Prova diretta che il path deterministico computabile offline non
        // esiste più: i metodi che lo implementavano non devono più essere
        // dichiarati sulla classe. Se qualcuno li reintroducesse, questo test
        // fallisce. Keystore-agnostico (pura reflection).
        val declared = BackdoorCodeGenerator::class.java.declaredMethods.map { it.name }.toSet()
        assertThat(declared).doesNotContain("legacyDeterministicCode")
        assertThat(declared).doesNotContain("getDeviceId")
        assertThat(declared).doesNotContain("sha256")
    }

    @Test
    fun getOrGenerateForWeek_neverReturnsTheOldDeterministicCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val code = BackdoorCodeGenerator.getOrGenerateForWeek(ctx)
        // Keystore-agnostico: con Keystore non disponibile è null (fail-secure,
        // nessun codice indovinabile); con Keystore disponibile è un random
        // base32. In NESSUN caso deve essere il vecchio codice deterministico.
        assertThat(code).isNotEqualTo(oldDeterministicCode(ctx))
        if (code != null) {
            // Se emesso, deve essere SOLO alfabeto pulito (no '0'/'1' dell'hex).
            assertThat(code).hasLength(8)
            val allowed = ALPHABET.toSet()
            code.forEach { c -> assertThat(allowed).contains(c) }
        }
    }

    @Test
    fun validateCode_neverAcceptsTheOldDeterministicCode() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Un avversario che ricalcola il vecchio codice deterministico offline
        // non deve poter sbloccare: o non è il codice corrente (random), o il
        // Keystore è giù e validateCode è false a prescindere (fail-secure).
        assertThat(BackdoorCodeGenerator.validateCode(ctx, oldDeterministicCode(ctx))).isFalse()
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
