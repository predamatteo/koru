package com.dev.koru.strictmode

import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.MessageDigest
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
 * Migration: la prima volta che vengono chiamati su un dispositivo che NON ha
 * code in store, bootstrappiamo con il valore deterministico (compatibilità
 * coi codici già scritti su carta dall'utente). Da quel momento la rotazione
 * settimanale avviene generando un nuovo random — `getOrGenerateForWeek`
 * controlla la settimana e ruota automaticamente.
 */
object BackdoorCodeGenerator {
    private const val TAG = "BackdoorCodeGen"
    private const val SALT = "koru_strict_v1"
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
    fun generateCurrentCode(context: Context): String = getOrGenerateForWeek(context)

    /// Compat alias storico (parte della ownership dichiarata dal coordinatore).
    fun forWeek(context: Context): String = getOrGenerateForWeek(context)

    /// Ritorna il code della settimana corrente. Se non esiste o la settimana
    /// è cambiata rispetto a quella salvata, ne genera uno nuovo e lo persiste.
    /// Sul primo accesso assoluto (nessun code in store) usiamo bootstrap
    /// deterministico per backward-compat con utenti che hanno già trascritto
    /// il codice di questa settimana.
    fun getOrGenerateForWeek(context: Context): String {
        val prefs = encryptedPrefs(context) ?: return legacyDeterministicCode(context)
        val savedCode = prefs.getString(KEY_CURRENT_CODE, null)
        val savedWeek = prefs.getString(KEY_CURRENT_WEEK, null)
        val currentWeek = getCurrentWeekKey()

        if (!savedCode.isNullOrBlank() && savedWeek == currentWeek) {
            return savedCode
        }

        val newCode = if (savedCode.isNullOrBlank() && savedWeek == null) {
            // Bootstrap iniziale: backward-compat con codice deterministico
            // della settimana corrente (se l'utente l'aveva annotato prima
            // dell'upgrade, deve continuare a funzionare).
            legacyDeterministicCode(context)
        } else {
            // Settimana ruotata: nuovo code random Keystore-backed.
            randomBase32(CODE_LENGTH)
        }

        prefs.edit()
            .putString(KEY_CURRENT_CODE, newCode)
            .putString(KEY_CURRENT_WEEK, currentWeek)
            .apply()
        return newCode
    }

    /// Validazione: leggere dallo store, non ricomputare. La match è
    /// case-insensitive (ALPHABET è già uppercase) e tollera spazi.
    /// Nota: il caller deve gestire counter di lockout + marca-come-usato.
    fun validateCode(context: Context, code: String): Boolean {
        val expected = getOrGenerateForWeek(context).trim().uppercase()
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
            // Su Keystore corrotto (rara, succede dopo factory reset
            // su alcuni device): degradiamo silentemente al codice
            // deterministico. La sicurezza si abbassa ma l'utente non
            // resta locked out dello strict mode.
            Log.e(TAG, "EncryptedSharedPreferences unavailable: ${e.message}")
            null
        }
    }

    private fun legacyDeterministicCode(context: Context): String {
        val deviceId = getDeviceId(context)
        val weekKey = getCurrentWeekKey()
        val input = "$deviceId:$weekKey:$SALT"
        // 8 hex chars uppercase = 32 bit — meno entropia del nostro 8-char
        // base32 (40 bit) ma ok come bootstrap. Convertiamo solo per
        // restare retro-compatibili coi code stampati dall'utente.
        return sha256(input).substring(0, 8).uppercase()
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

    private fun getDeviceId(context: Context): String =
        Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"

    private fun getCurrentWeekKey(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-W${cal.get(Calendar.WEEK_OF_YEAR)}"
    }

    private fun sha256(input: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        return md.digest(input.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
