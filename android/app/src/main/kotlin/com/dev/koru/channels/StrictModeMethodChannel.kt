package com.dev.koru.channels

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.dev.koru.db.NativeDatabase
import com.dev.koru.strictmode.BackdoorCodeGenerator
import com.dev.koru.strictmode.KoruDeviceAdminReceiver
import com.dev.koru.strictmode.StrictModeEnforcer
import com.dev.koru.strictmode.StrictModeStore
import com.dev.koru.strictmode.UnblockTokenStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel `com.koru/strict_mode`.
 *
 * Owns la validazione del backdoor code lato native con:
 * - Rate limiting esponenziale: 5/24h/72h lockout dopo tentativi falliti.
 * - Replay protection: ogni code è single-use (set in EncryptedSharedPreferences
 *   + idealmente sync con tabella `used_backdoor_codes` nel DB Drift).
 * - Atomic unblock: validate → markUsed → setMask(0) tutto in un handler.
 * - Device admin guard: `disableDeviceAdmin` rifiuta se strict mode è attivo.
 *
 * Baseline temporali: usiamo [SystemClock.elapsedRealtime] (monotonic clock,
 * non manipolabile dall'utente cambiando l'orologio di sistema) come reference
 * per il lockout. La last-attempt è persistita come elapsedRealtime delta
 * rispetto a un anchor salvato la prima volta, riallineato all'occorrenza
 * di un reboot (signal: `currentTimeMillis - elapsedRealtime` cambia).
 */
object StrictModeMethodChannel {
    private const val TAG = "StrictModeCh"
    private const val CHANNEL = "com.koru/strict_mode"

    // EncryptedSharedPreferences per i counter di lockout + set di code usati.
    private const val PREFS_NAME = "koru_backdoor_state"
    private const val KEY_FAIL_COUNT = "fail_count"
    private const val KEY_LAST_FAIL_ELAPSED = "last_fail_elapsed_ms"
    private const val KEY_LAST_FAIL_WALL = "last_fail_wall_ms"
    private const val KEY_USED_CODES = "used_codes_set"

    // Soglie di rate limit. Sequenza: dopo 3 tentativi falliti lockout
    // di 5 min; dopo 5 tentativi 24h; dopo 7+ tentativi 72h. Granularità
    // pensata per evitare brute force su un keyspace 40-bit (32^8) ma
    // restando umana per l'utente che ha sbagliato a digitare.
    private const val THRESHOLD_SOFT = 3
    private const val LOCKOUT_SOFT_MS = 5L * 60L * 1000L     // 5 minuti
    private const val THRESHOLD_MEDIUM = 5
    private const val LOCKOUT_MEDIUM_MS = 24L * 60L * 60L * 1000L  // 24 ore
    private const val THRESHOLD_HARD = 7
    private const val LOCKOUT_HARD_MS = 72L * 60L * 60L * 1000L    // 72 ore

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableDeviceAdmin" -> {
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component)
                            putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "Koru needs Device Admin to lock Settings/Recent/Uninstall while Strict Mode is active."
                            )
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    }
                    "disableDeviceAdmin" -> {
                        // Guard: rifiutiamo se strict mode è attivo. L'utente
                        // DEVE prima passare il backdoor code (che azzera la mask),
                        // poi potrà disabilitare il device admin. Altrimenti
                        // il device admin sarebbe un trivial bypass.
                        val mask = StrictModeStore.readMask(activity)
                        if (mask != 0) {
                            result.error(
                                "STRICT_ACTIVE",
                                "Cannot disable device admin while strict mode is active. " +
                                    "Use the backdoor code to disable strict mode first.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        if (dpm.isAdminActive(component)) dpm.removeActiveAdmin(component)
                        result.success(true)
                    }
                    "isDeviceAdminActive" -> {
                        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        result.success(dpm.isAdminActive(component))
                    }
                    "setStrictModeOptions" -> {
                        // SEC-01: il gate di autorizzazione vive QUI (native), non
                        // solo nell'UI Dart. ALZARE la mask (aggiungere restrizioni)
                        // resta libero — è la direzione fail-secure. SPEGNERE un bit
                        // attivo (downgrade) richiede un token monouso emesso solo
                        // dopo una validazione riuscita del backdoor code
                        // (UnblockTokenStore), consumato atomicamente (no replay).
                        // Mirror del guard di `disableDeviceAdmin` sopra.
                        val newMask = call.argument<Int>("mask") ?: 0
                        val oldMask = StrictModeStore.readMask(activity)
                        val token = call.argument<String>("unblockToken")
                        if (clearsActiveBit(oldMask, newMask) &&
                            !UnblockTokenStore.consume(token)
                        ) {
                            Log.w(TAG, "setStrictModeOptions DENIED: downgrade $oldMask→$newMask without valid token")
                            result.error(
                                "UNAUTHORIZED",
                                "Disabling strict-mode restrictions requires a valid backdoor unblock token.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        Log.i(TAG, "setStrictModeOptions: $oldMask→$newMask")
                        StrictModeStore.saveMask(activity, newMask)
                        StrictModeEnforcer.invalidateCache()
                        result.success(null)
                    }
                    "getStrictModeOptions" -> {
                        result.success(StrictModeStore.readMask(activity))
                    }
                    "generateBackdoorCode" -> {
                        result.success(BackdoorCodeGenerator.generateCurrentCode(activity))
                    }
                    "getRemainingAttempts" -> {
                        // Espone all'UI quanti tentativi rimangono prima del
                        // prossimo lockout. Trasparenza: l'utente capisce
                        // l'imminenza del lockout.
                        result.success(remainingAttempts(activity))
                    }
                    "getLockoutRemainingMs" -> {
                        // Ms rimanenti se siamo dentro un lockout, altrimenti 0.
                        result.success(lockoutRemainingMs(activity))
                    }
                    "validateBackdoorCode" -> {
                        val code = call.argument<String>("code") ?: ""
                        val outcome = validateBackdoorCodeWithLockout(activity, code)
                        when (outcome) {
                            is BackdoorOutcome.Locked -> result.error(
                                "LOCKED_OUT",
                                "Too many failed attempts. Try again in ${outcome.remainingMs}ms.",
                                outcome.remainingMs,
                            )
                            is BackdoorOutcome.Replay -> result.error(
                                "REPLAY",
                                "This code has already been used. Wait for the next weekly rotation.",
                                null,
                            )
                            BackdoorOutcome.Valid -> {
                                // SEC-01: emetti un token monouso che autorizza un
                                // successivo `setStrictModeOptions` a SPEGNERE bit
                                // attivi. Ritorniamo il token (string) invece di un
                                // bool: il Dart lo cattura e lo ripassa.
                                result.success(UnblockTokenStore.issue())
                            }
                            BackdoorOutcome.Invalid -> result.success(null)
                        }
                    }
                    "performEmergencyUnblock" -> {
                        // Atomic: validate + markUsed + setMask(0). Il code è
                        // ora un parametro obbligatorio (no più "unblock senza
                        // verifica" come prima).
                        val code = call.argument<String>("code") ?: ""
                        val outcome = validateBackdoorCodeWithLockout(activity, code)
                        when (outcome) {
                            is BackdoorOutcome.Locked -> {
                                result.error(
                                    "LOCKED_OUT",
                                    "Too many failed attempts. Try again in ${outcome.remainingMs}ms.",
                                    outcome.remainingMs,
                                )
                                return@setMethodCallHandler
                            }
                            is BackdoorOutcome.Replay -> {
                                result.error(
                                    "REPLAY",
                                    "This code has already been used.",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                            BackdoorOutcome.Invalid -> {
                                result.error("INVALID_CODE", "Invalid backdoor code.", null)
                                return@setMethodCallHandler
                            }
                            BackdoorOutcome.Valid -> {
                                // OK: mask=0, ruotiamo il code (single-use forte),
                                // logghiamo l'evento, e rimuoviamo device admin.
                                StrictModeStore.saveMask(activity, 0)
                                StrictModeEnforcer.invalidateCache()
                                BackdoorCodeGenerator.rotate(activity)
                                try {
                                    val db = NativeDatabase.open(activity)
                                    db.execSQL(
                                        "INSERT INTO emergency_unblocks (timestamp) VALUES (?)",
                                        arrayOf(System.currentTimeMillis()),
                                    )
                                } catch (_: Exception) {}
                                val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE)
                                    as DevicePolicyManager
                                val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                                if (dpm.isAdminActive(component)) dpm.removeActiveAdmin(component)
                                result.success(true)
                            }
                        }
                    }
                    "isStrictModeActive" -> {
                        result.success(StrictModeStore.readMask(activity) != 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private sealed class BackdoorOutcome {
        data class Locked(val remainingMs: Long) : BackdoorOutcome()
        object Replay : BackdoorOutcome()
        object Valid : BackdoorOutcome()
        object Invalid : BackdoorOutcome()
    }

    /// SEC-01: true se passare da [oldMask] a [newMask] SPEGNE almeno un bit
    /// che era attivo (downgrade della protezione). Condizione equivalente a
    /// `newMask & oldMask != oldMask`: se `newMask` è un superset di `oldMask`
    /// (solo bit aggiunti) l'AND riproduce `oldMask` e non c'è downgrade.
    /// Solo i downgrade richiedono il token monouso; alzare la mask è libero.
    /// `internal` per essere unit-testabile senza riflessione.
    internal fun clearsActiveBit(oldMask: Int, newMask: Int): Boolean =
        (newMask and oldMask) != oldMask

    /// Validazione atomica del code: check lockout → check replay → check match.
    /// In caso di match marca il code come usato e azzera il counter dei fail.
    /// In caso di miss, incrementa il counter e ritorna Invalid (o Locked se
    /// la soglia successiva è stata superata).
    private fun validateBackdoorCodeWithLockout(
        context: Context,
        code: String,
    ): BackdoorOutcome {
        val remaining = lockoutRemainingMs(context)
        if (remaining > 0) {
            return BackdoorOutcome.Locked(remaining)
        }

        val normalized = code.trim().uppercase()
        if (normalized.isEmpty()) {
            recordFailedAttempt(context)
            return BackdoorOutcome.Invalid
        }

        // Replay check: questo specifico code è già stato usato?
        if (isCodeUsed(context, normalized)) {
            // Non incrementiamo il counter qui: l'utente ha digitato un code
            // che era già valido (non sta brute-forzando). Ritorna Replay
            // così l'UI può spiegare e suggerire di aspettare la rotazione.
            return BackdoorOutcome.Replay
        }

        val matches = BackdoorCodeGenerator.validateCode(context, normalized)
        if (matches) {
            markCodeUsed(context, normalized)
            resetFailedAttempts(context)
            // Tentativo opzionale di scrittura nella tabella DB (audit log).
            try {
                val db = NativeDatabase.open(context)
                db.execSQL(
                    "INSERT OR IGNORE INTO used_backdoor_codes (code, used_at) VALUES (?, ?)",
                    arrayOf(normalized, System.currentTimeMillis()),
                )
            } catch (_: Exception) {}
            return BackdoorOutcome.Valid
        }

        recordFailedAttempt(context)
        // Se l'incremento ha attivato un lockout, segnaliamo Locked invece di Invalid.
        val remainingAfter = lockoutRemainingMs(context)
        return if (remainingAfter > 0) BackdoorOutcome.Locked(remainingAfter) else BackdoorOutcome.Invalid
    }

    private fun isCodeUsed(context: Context, code: String): Boolean {
        val prefs = prefs(context) ?: return false
        val used = prefs.getStringSet(KEY_USED_CODES, emptySet()) ?: emptySet()
        return used.contains(code)
    }

    private fun markCodeUsed(context: Context, code: String) {
        val prefs = prefs(context) ?: return
        val current = prefs.getStringSet(KEY_USED_CODES, emptySet())?.toMutableSet() ?: mutableSetOf()
        current += code
        // Cap del set: dopo 100 entries, droppa le più vecchie (in pratica
        // mai raggiunto, ma evita unbounded growth se l'utente trigge-asse
        // emergency unblock decine di volte). Set non è ordinato — droppiamo
        // semplicemente entries random.
        if (current.size > 100) {
            val toRemove = current.size - 100
            val iter = current.iterator()
            repeat(toRemove) {
                if (iter.hasNext()) {
                    iter.next()
                    iter.remove()
                }
            }
        }
        prefs.edit().putStringSet(KEY_USED_CODES, current).apply()
    }

    private fun recordFailedAttempt(context: Context) {
        val prefs = prefs(context) ?: return
        val current = prefs.getInt(KEY_FAIL_COUNT, 0) + 1
        prefs.edit()
            .putInt(KEY_FAIL_COUNT, current)
            .putLong(KEY_LAST_FAIL_ELAPSED, SystemClock.elapsedRealtime())
            .putLong(KEY_LAST_FAIL_WALL, System.currentTimeMillis())
            .apply()
        Log.w(TAG, "Failed backdoor attempt #$current")
    }

    private fun resetFailedAttempts(context: Context) {
        val prefs = prefs(context) ?: return
        prefs.edit()
            .remove(KEY_FAIL_COUNT)
            .remove(KEY_LAST_FAIL_ELAPSED)
            .remove(KEY_LAST_FAIL_WALL)
            .apply()
    }

    private fun remainingAttempts(context: Context): Int {
        val prefs = prefs(context) ?: return THRESHOLD_HARD
        val failCount = prefs.getInt(KEY_FAIL_COUNT, 0)
        return when {
            failCount < THRESHOLD_SOFT -> THRESHOLD_SOFT - failCount
            failCount < THRESHOLD_MEDIUM -> THRESHOLD_MEDIUM - failCount
            failCount < THRESHOLD_HARD -> THRESHOLD_HARD - failCount
            else -> 0
        }
    }

    /// Quanti ms mancano alla fine del lockout corrente; 0 se non in lockout.
    /// Usa elapsedRealtime quando possibile (monotonic, no time tampering).
    /// Dopo un reboot elapsedRealtime si azzera: in quel caso usiamo il
    /// wall clock come fallback approssimato.
    private fun lockoutRemainingMs(context: Context): Long {
        val prefs = prefs(context) ?: return 0L
        val failCount = prefs.getInt(KEY_FAIL_COUNT, 0)
        if (failCount < THRESHOLD_SOFT) return 0L

        val lockoutDuration = when {
            failCount >= THRESHOLD_HARD -> LOCKOUT_HARD_MS
            failCount >= THRESHOLD_MEDIUM -> LOCKOUT_MEDIUM_MS
            else -> LOCKOUT_SOFT_MS
        }

        val lastFailElapsed = prefs.getLong(KEY_LAST_FAIL_ELAPSED, 0L)
        val lastFailWall = prefs.getLong(KEY_LAST_FAIL_WALL, 0L)
        val nowElapsed = SystemClock.elapsedRealtime()
        val nowWall = System.currentTimeMillis()

        // Detect reboot: elapsedRealtime al momento del fail era maggiore
        // di quello attuale → device è stato riavviato. In quel caso fidiamoci
        // del wall clock (l'utente potrebbe averlo mosso, ma è meglio di niente).
        val sinceFail = if (lastFailElapsed > 0L && lastFailElapsed <= nowElapsed) {
            nowElapsed - lastFailElapsed
        } else if (lastFailWall > 0L && nowWall >= lastFailWall) {
            nowWall - lastFailWall
        } else {
            // Wall clock spostato indietro: assumiamo che il lockout sia
            // appena iniziato (fail-secure: l'utente non sblocca a botta
            // di NTP manipulation).
            0L
        }

        val remaining = lockoutDuration - sinceFail
        return if (remaining > 0L) remaining else 0L
    }

    private fun prefs(context: Context): SharedPreferences? {
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
