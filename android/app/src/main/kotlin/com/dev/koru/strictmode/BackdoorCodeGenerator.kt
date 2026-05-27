package com.dev.koru.strictmode

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.SecureRandom
import java.util.Calendar

/**
 * Backdoor code per disattivare Strict Mode quando l'utente è in crisi.
 *
 * Storia: il codice era derivato deterministicamente da ANDROID_ID + week + salt.
 * Problema: chiunque conoscesse l'ANDROID_ID poteva calcolare il code offline,
 * e gli ANDROID_ID si leakano spesso (debugging tools, app con READ_PHONE_STATE
 * etc.). Inoltre il code era "stateless" — non c'era modo di marcarlo come
 * usato. Ora: il primo `forWeek/generateCurrentCode` genera un code casuale
 * (SecureRandom, 8 caratteri base32) e lo salva in EncryptedSharedPreferences
 * Keystore-backed. La validazione legge dallo store, non ricomputa.
 *
 * SEC-10 — fail-secure su Keystore non disponibile. PRIMA: se
 * EncryptedSharedPreferences non era creabile (Keystore corrotto) si degradava
 * a un codice deterministico `SHA-256(ANDROID_ID‖week‖salt)` troncato a 32 bit.
 * Ma l'ANDROID_ID è leakabile e il salt è nel repo open-source → quel codice
 * settimanale era calcolabile offline da un avversario (= l'utente stesso).
 * ORA: se il Keystore non è disponibile NON emettiamo alcun codice — ritorniamo
 * `null`. L'UI mostra "temporaneamente non disponibile, riprova" invece di un
 * codice indovinabile. Meglio non poter sbloccare (riprova quando il Keystore
 * torna) che offrire una backdoor computabile. Il bootstrap deterministico per
 * le NUOVE installazioni è stato rimosso: il primo codice è sempre random.
 *
 * Continuità upgrade: un codice GIÀ salvato (anche se generato dal vecchio
 * bootstrap deterministico) continua a essere letto e validato finché la
 * settimana non ruota — non azzeriamo nulla.
 */
object BackdoorCodeGenerator {
    private const val TAG = "BackdoorCodeGen"
    private const val PREFS_NAME = "koru_backdoor_secure"
    private const val KEY_CURRENT_CODE = "current_code"
    private const val KEY_CURRENT_WEEK = "current_week"

    // Base32 senza caratteri ambigui (no 0/O/1/I/L). 32 simboli puliti per
    // dettatura vocale e trascrizione su carta.
    private const val ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    private const val CODE_LENGTH = 8

    private val secureRandom = SecureRandom()

    /// Compat shim: il vecchio `generateCurrentCode` è ora un alias di
    /// [getOrGenerateForWeek]. Mantiene la firma per i call site esistenti.
    /// `null` ⇒ Keystore non disponibile (SEC-10): nessun codice da mostrare.
    fun generateCurrentCode(context: Context): String? = getOrGenerateForWeek(context)

    /// Compat alias storico (parte della ownership dichiarata dal coordinatore).
    fun forWeek(context: Context): String? = getOrGenerateForWeek(context)

    /// Ritorna il code della settimana corrente, o `null` se il Keystore non è
    /// disponibile (SEC-10: fail-secure, niente codice deterministico). Se la
    /// settimana è cambiata rispetto a quella salvata ne genera uno nuovo random
    /// e lo persiste; un codice già salvato viene restituito as-is (continuità
    /// upgrade). NON esiste più un bootstrap deterministico per le nuove
    /// installazioni: il primo codice è sempre [randomBase32].
    fun getOrGenerateForWeek(context: Context): String? {
        // SEC-10: senza Keystore non emettiamo nulla. Un tempo qui c'era
        // `?: return legacyDeterministicCode(context)` → codice calcolabile
        // offline. Ora fail-secure: l'UI gestisce il null come "riprova".
        val prefs = encryptedPrefs(context) ?: return null
        val savedCode = prefs.getString(KEY_CURRENT_CODE, null)
        val savedWeek = prefs.getString(KEY_CURRENT_WEEK, null)
        val currentWeek = getCurrentWeekKey()

        if (!savedCode.isNullOrBlank() && savedWeek == currentWeek) {
            return savedCode
        }

        // Primo accesso assoluto O settimana ruotata: nuovo code random
        // Keystore-backed. (Rimosso il bootstrap deterministico — SEC-10.)
        val newCode = randomBase32(CODE_LENGTH)
        prefs.edit()
            .putString(KEY_CURRENT_CODE, newCode)
            .putString(KEY_CURRENT_WEEK, currentWeek)
            .apply()
        return newCode
    }

    /// Validazione: leggere dallo store, non ricomputare. La match è
    /// case-insensitive (ALPHABET è già uppercase) e tollera spazi.
    /// Nota: il caller deve gestire counter di lockout + marca-come-usato.
    /// SEC-10: se non c'è un codice corrente (Keystore non disponibile) ritorna
    /// false → nessun input sblocca (fail-secure), non si downgrada a un
    /// confronto contro un codice indovinabile.
    fun validateCode(context: Context, code: String): Boolean {
        val expected = getOrGenerateForWeek(context)?.trim()?.uppercase() ?: return false
        val input = code.trim().uppercase()
        if (expected.isEmpty() || input.isEmpty()) return false
        // Constant-time compare: evita timing side channel sul check char-by-char.
        return constantTimeEquals(expected, input)
    }

    /// Force-rotate del code (chiamato dopo emergency unblock o per debug).
    /// Sostituisce immediatamente il code con uno nuovo random e re-allinea
    /// la settimana corrente.
    fun rotate(context: Context) {
        val prefs = encryptedPrefs(context) ?: return
        prefs.edit()
            .putString(KEY_CURRENT_CODE, randomBase32(CODE_LENGTH))
            .putString(KEY_CURRENT_WEEK, getCurrentWeekKey())
            .apply()
    }

    private fun encryptedPrefs(context: Context): SharedPreferences? {
        return try {
            val masterKey = MasterKey.Builder(context.applicationContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                context.applicationContext,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            // Keystore non disponibile (raro, puo' capitare dopo un factory
            // reset su alcuni device): ritorniamo null. Il chiamante
            // (getOrGenerateForWeek) fa FAIL-SECURE — nessun codice emesso
            // (il vecchio fallback deterministico/indovinabile da ANDROID_ID
            // e' stato rimosso con SEC-10) e validateCode rifiuta ogni input,
            // quindi lo strict mode resta applicato; l'UI mostra "codice
            // temporaneamente non disponibile, riprova".
            Log.e(TAG, "EncryptedSharedPreferences unavailable: ${e.message}")
            null
        }
    }

    private fun randomBase32(length: Int): String {
        val sb = StringBuilder(length)
        repeat(length) {
            sb.append(ALPHABET[secureRandom.nextInt(ALPHABET.length)])
        }
        return sb.toString()
    }

    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].code xor b[i].code)
        }
        return result == 0
    }

    private fun getCurrentWeekKey(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-W${cal.get(Calendar.WEEK_OF_YEAR)}"
    }
}
