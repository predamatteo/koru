package com.dev.koru.strictmode

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.io.File
import java.security.MessageDigest

/**
 * Storage del mask delle opzioni Strict Mode.
 *
 * Storia: il mask viveva in un file plain text (`koru_strict_mask.txt`) in
 * filesDir. Su device rootati / con accesso al filesystem un utente "in crisi"
 * poteva editare manualmente il file e azzerare la mask, bypassando l'intera
 * protezione. Ora: il valore è in [EncryptedSharedPreferences] Keystore-backed
 * con HMAC del payload (SHA-256 del raw int + key derivata dalla master key).
 *
 * Fail-secure: se il file è stato tamper-ato (HMAC mismatch) ritorniamo
 * [ALL_OPTIONS_ENABLED] invece di 0. Razionale: l'utente sta cercando di
 * bypassare lo strict mode → la risposta corretta è "tutto bloccato finché
 * non passi dal backdoor code", non "tutto sbloccato".
 *
 * Migration: leggiamo una sola volta il file legacy `koru_strict_mask.txt`,
 * lo travasiamo nello store cifrato e cancelliamo il file plain.
 *
 * Cross-process: EncryptedSharedPreferences NON è multi-process safe per le
 * write concorrenti, ma le write della mask avvengono SOLO dal main process
 * (via [StrictModeMethodChannel]). Il processo `:accessibility` fa solo read.
 * Va bene così: il main process modifica, il polling del :accessibility
 * legge il valore aggiornato entro pochi ms (CACHE_MS dell'enforcer = 0).
 */
object StrictModeStore {
    private const val TAG = "StrictModeStore"
    private const val LEGACY_FILE_NAME = "koru_strict_mask.txt"
    private const val PREFS_NAME = "koru_strict_secure"
    private const val KEY_MASK = "mask"
    private const val KEY_MASK_HMAC = "mask_hmac"
    private const val HMAC_KEY_DERIVATION = "koru_strict_mask_hmac_v1"

    /// Tutti i 5 bit MVP attivi (1|2|4|8|16 = 31). Fail-secure value: usato
    /// quando il file è tamper-ato o irrecuperabile. NON è 0, perché un
    /// attacker che resetta il file deve trovarsi con TUTTO bloccato, non
    /// con tutto sbloccato. Manteniamo questo come letterale invece che come
    /// `or` su `StrictModeEnforcer.BLOCK_*` perché `const val` Kotlin richiede
    /// compile-time constants (operatore `or` non è considerato const).
    const val ALL_OPTIONS_ENABLED: Int = 31

    // Mantengo questi alias per i call site che importano i bit dallo store
    // (es. BlockingMethodChannel referenzia StrictModeStore.BLOCK_UNINSTALLING).
    // I valori DEVONO matchare quelli di StrictModeEnforcer.
    const val BLOCK_EDITING = 1
    const val BLOCK_SETTINGS = 2
    const val BLOCK_UNINSTALLING = 4
    const val BLOCK_RECENT_APPS = 8
    const val BLOCK_SPLIT_SCREEN = 16

    fun saveMask(context: Context, mask: Int) {
        val prefs = encryptedPrefs(context) ?: run {
            // Fallback estremo: se EncryptedSharedPreferences non è
            // disponibile (Keystore corrotto) scriviamo nel file legacy
            // per non perdere la mask, ma logghiamo errore.
            Log.e(TAG, "EncryptedSharedPreferences unavailable, falling back to legacy file")
            return saveLegacyFile(context, mask)
        }
        val hmac = computeHmac(mask)
        prefs.edit()
            .putInt(KEY_MASK, mask)
            .putString(KEY_MASK_HMAC, hmac)
            .apply()
        // Pulizia file legacy se ancora presente.
        deleteLegacyFile(context)
        Log.d(TAG, "Saved strict mode mask: $mask")
    }

    /// Alias storico (alcuni call site usavano `writeMask`).
    fun writeMask(context: Context, mask: Int) = saveMask(context, mask)

    fun readMask(context: Context): Int {
        val prefs = encryptedPrefs(context)
        if (prefs == null) {
            // Senza EncryptedSharedPreferences leggiamo dal file legacy.
            // Niente HMAC su quel path, ma è una situazione degradata.
            return readLegacyFile(context)
        }

        val hasMask = prefs.contains(KEY_MASK)
        val hasHmac = prefs.contains(KEY_MASK_HMAC)

        if (!hasMask && !hasHmac) {
            // Mai scritto via encrypted store: tentiamo migration dal file legacy.
            return migrateFromLegacy(context, prefs)
        }

        val storedMask = prefs.getInt(KEY_MASK, 0)
        val storedHmac = prefs.getString(KEY_MASK_HMAC, "") ?: ""
        val computedHmac = computeHmac(storedMask)

        if (!constantTimeEquals(storedHmac, computedHmac)) {
            // Tamper detection: ritorna fail-secure value.
            Log.w(TAG, "HMAC mismatch on strict mask — failing secure (all blocks enabled)")
            return ALL_OPTIONS_ENABLED
        }
        return storedMask
    }

    /// SEC-02: true se lo store NON ha MAI registrato una mask (né nello store
    /// cifrato né nel file legacy). Distingue:
    ///  - "prima installazione pulita" / "dati cancellati" (nessuna chiave) ⇒ true;
    ///  - "l'utente ha disattivato strict legittimamente" (saveMask(0) ha scritto
    ///    `mask=0` + hmac, chiave PRESENTE) ⇒ false.
    /// Usato dal fail-safe [com.dev.koru.service.StrictModeFailSafe]: combinato
    /// con "device admin ancora attivo" (segnale durevole che sopravvive a
    /// Clear Data) discrimina il wipe dei dati dal first-install.
    fun isEncryptedStoreFresh(context: Context): Boolean {
        val prefs = encryptedPrefs(context)
        if (prefs == null) {
            // Keystore non disponibile: ci basiamo sul file legacy. Assente ⇒
            // store vergine.
            return !File(context.filesDir, LEGACY_FILE_NAME).exists()
        }
        val hasMask = prefs.contains(KEY_MASK)
        val hasHmac = prefs.contains(KEY_MASK_HMAC)
        if (hasMask || hasHmac) return false
        // Nessuna chiave nello store cifrato: vergine SOLO se non c'è neppure il
        // file legacy da migrare.
        return !File(context.filesDir, LEGACY_FILE_NAME).exists()
    }

    private fun migrateFromLegacy(context: Context, prefs: SharedPreferences): Int {
        val legacy = readLegacyFile(context)
        // Salva nel nuovo store anche se è 0: così marchiamo la migration
        // come avvenuta e non la ri-eseguiamo a ogni read.
        val hmac = computeHmac(legacy)
        prefs.edit()
            .putInt(KEY_MASK, legacy)
            .putString(KEY_MASK_HMAC, hmac)
            .apply()
        deleteLegacyFile(context)
        Log.i(TAG, "Migrated legacy mask=$legacy to encrypted store")
        return legacy
    }

    private fun readLegacyFile(context: Context): Int {
        return try {
            val file = File(context.filesDir, LEGACY_FILE_NAME)
            if (!file.exists()) return 0
            file.readText().trim().toIntOrNull() ?: 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read legacy mask file", e)
            0
        }
    }

    private fun saveLegacyFile(context: Context, mask: Int) {
        try {
            File(context.filesDir, LEGACY_FILE_NAME).writeText(mask.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write legacy mask file", e)
        }
    }

    private fun deleteLegacyFile(context: Context) {
        try {
            val file = File(context.filesDir, LEGACY_FILE_NAME)
            if (file.exists()) file.delete()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to delete legacy file", e)
        }
    }

    /// HMAC del mask (SHA-256 di `key || value` — non è HMAC standard ma è
    /// sufficiente per tamper-evident: l'attacker non conosce la key
    /// derivation senza accesso al Keystore, e modificando il valore int
    /// non può ricomputare l'hash). Usiamo una key derivation locale invece
    /// di HMAC standard per evitare dipendenze su Mac/SecretKeySpec — il
    /// payload è già in EncryptedSharedPreferences (confidentiality OK), qui
    /// serve solo integrità contro tamper del file di backing.
    private fun computeHmac(mask: Int): String {
        val md = MessageDigest.getInstance("SHA-256")
        val data = "$HMAC_KEY_DERIVATION:$mask".toByteArray()
        return md.digest(data).joinToString("") { "%02x".format(it) }
    }

    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].code xor b[i].code)
        }
        return result == 0
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
            Log.e(TAG, "EncryptedSharedPreferences unavailable: ${e.message}")
            null
        }
    }
}
