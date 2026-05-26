package com.dev.koru.strictmode

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.dev.koru.MainActivity

/**
 * SEC-02 — strato fail-secure contro il reset dello strict mode via
 * "Cancella dati" dell'app.
 *
 * Problema: senza Device Owner, "Impostazioni → App → Koru → Cancella dati"
 * azzera TUTTO lo stato di anti-aggiramento (mask cifrata, contatori, lockout).
 * `StrictModeStore` fallisce già secure quando un RECORD ESISTENTE è manomesso
 * (HMAC mismatch ⇒ [StrictModeStore.ALL_OPTIONS_ENABLED]); il gap è il caso
 * STORE VUOTO post-wipe, indistinguibile da una prima installazione pulita.
 *
 * Idea (best-effort, esplicitamente endorsed dalla review): serve un segnale
 * DUREVOLE di "strict era attivo" che un Clear Data NON cancelli. Il candidato
 * naturale è lo stato del **Device Admin**: l'iscrizione come admin è tenuta
 * dal sistema (`DevicePolicyManager`), NON nella dir dati dell'app, quindi
 * sopravvive a Clear Data. E abilitare lo strict mode RICHIEDE il device admin
 * (vedi `strict_mode_screen`: `enableDeviceAdmin()` precede `setStrictModeOptions`).
 *
 * Discriminante preciso (vedi [shouldReassert]):
 *   `deviceAdminAttivo && storeVergine` ⇒ TAMPERING (i dati sono stati
 *   cancellati mentre lo strict era armato) ⇒ ri-arma a
 *   [StrictModeStore.ALL_OPTIONS_ENABLED] e notifica.
 *
 * Perché NON ci sono falsi positivi sul disable legittimo: ogni disattivazione
 * regolare dello strict scrive `mask=0` (via `StrictModeStore.saveMask(_, 0)`
 * in `setStrictModeOptions` o `performEmergencyUnblock`), quindi la chiave
 * `mask` ESISTE → [StrictModeStore.isEncryptedStoreFresh] = false. E rimuovere
 * il device admin scrive comunque `mask=0` ([KoruDeviceAdminReceiver.onDisabled]).
 * Una prima installazione pulita non ha device admin attivo → nessun re-arm.
 *
 * Limiti RESIDUI (documentati, non risolvibili senza Device Owner):
 * - Se l'utente cancella i dati E poi rimuove anche il device admin dalle
 *   Impostazioni, il segnale durevole sparisce → reset completo riuscito.
 *   (Mitigazione UX: `onDisableRequested`/`onDisabled` deterrent già presenti.)
 * - Finestra stretta di falso positivo: device admin concesso ma app uccisa
 *   PRIMA di scrivere la mask. Esito = strict ri-armato a ALL + notifica;
 *   recuperabile dall'utente col backdoor code. Fail-secure, accettabile.
 * - `allowBackup=false` copre già `adb backup`.
 */
object StrictModeFailSafe {
    private const val TAG = "StrictModeFailSafe"
    private const val NOTIF_CHANNEL_ID = "koru_strict_mode_alerts"
    private const val NOTIF_CHANNEL_NAME = "Strict Mode Alerts"
    private const val NOTIF_ID_TAMPER_REASSERT = 4712

    /// Decisione PURA: ri-armare lo strict? True sse il device admin è attivo
    /// (segnale durevole "strict era armato") MA lo store è vergine (mask mai
    /// scritta ⇒ dati cancellati, non un disable legittimo). Unit-testabile.
    internal fun shouldReassert(deviceAdminActive: Boolean, storeFresh: Boolean): Boolean =
        deviceAdminActive && storeFresh

    /// Da chiamare all'avvio del servizio/app (processo di enforcement). Se
    /// rileva la firma di tampering, ri-arma la mask a ALL e mostra una
    /// notifica. Ritorna true se ha ri-armato. Idempotente: una volta scritta
    /// la mask (anche ALL), lo store non è più "vergine" → non ri-scatta.
    fun checkAndReassert(context: Context): Boolean {
        return try {
            val adminActive = isDeviceAdminActive(context)
            val fresh = StrictModeStore.isEncryptedStoreFresh(context)
            if (!shouldReassert(adminActive, fresh)) return false

            Log.w(
                TAG,
                "Tampering signature: device admin active but strict store empty " +
                    "(likely Clear Data) → re-asserting ALL_OPTIONS_ENABLED",
            )
            StrictModeStore.saveMask(context, StrictModeStore.ALL_OPTIONS_ENABLED)
            StrictModeEnforcer.invalidateCache()
            postTamperNotification(context)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Fail-safe check failed", e)
            false
        }
    }

    private fun isDeviceAdminActive(context: Context): Boolean {
        return try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
                ?: return false
            val component = ComponentName(context.applicationContext, KoruDeviceAdminReceiver::class.java)
            dpm.isAdminActive(component)
        } catch (e: Exception) {
            // Fail-secure direzione: se non possiamo verificare l'admin NON
            // ri-armiamo (evita loop di re-arm su errori di sistema); la difesa
            // resta il fail-secure dell'HMAC sui record esistenti.
            Log.w(TAG, "Cannot query device admin state", e)
            false
        }
    }

    private fun postTamperNotification(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (nm.getNotificationChannel(NOTIF_CHANNEL_ID) == null) {
                    val ch = NotificationChannel(
                        NOTIF_CHANNEL_ID,
                        NOTIF_CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply {
                        description = "Avvisi di disattivazione di funzionalità di sicurezza Koru."
                    }
                    nm.createNotificationChannel(ch)
                }
            }

            val tapIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val pi = PendingIntent.getActivity(
                context,
                0,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val notification = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("Strict mode ripristinato")
                .setContentText(
                    "I dati dell'app risultano azzerati con strict mode ancora armato. " +
                        "Per sicurezza le restrizioni sono state ripristinate.",
                )
                .setStyle(
                    NotificationCompat.BigTextStyle().bigText(
                        "Koru ha rilevato che i dati dell'app sono stati cancellati mentre lo " +
                            "strict mode era attivo. Le restrizioni sono state ripristinate. " +
                            "Usa il backdoor code per disattivarle in modo regolare.",
                    ),
                )
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pi)
                .build()

            nm.notify(NOTIF_ID_TAMPER_REASSERT, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post tamper notification", e)
        }
    }
}
