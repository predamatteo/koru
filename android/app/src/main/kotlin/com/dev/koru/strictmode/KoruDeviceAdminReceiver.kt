package com.dev.koru.strictmode

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.dev.koru.MainActivity

/**
 * Device Admin receiver per Koru Strict Mode.
 *
 * Hardening:
 * - [onDisableRequested]: se strict mode è ATTIVO, lanciamo MainActivity con
 *   un extra `require_backdoor_code=true` (l'UI Flutter mostrerà il dialog
 *   di backdoor in fullscreen). Restituiamo comunque una stringa di warning,
 *   ma la difesa primaria è l'activity fullscreen.
 * - [onDisabled]: se l'utente è riuscito comunque a disabilitarci (es. via
 *   Settings di sistema durante una corner-case), azzeriamo la mask per
 *   coerenza UI E mostriamo una notifica persistente per fare capire che
 *   la disabilitazione è permanente fino a re-enable manuale.
 *
 * Nota: Android NON permette di rifiutare programmaticamente la disable
 * request senza essere Device Owner (DPC mode), che richiede provisioning
 * tramite QR code/ADB su un dispositivo factory-reset. Quindi non è
 * possibile un "vero" lock — solo deterrent via UX + audit log.
 */
class KoruDeviceAdminReceiver : DeviceAdminReceiver() {
    companion object {
        private const val TAG = "KoruDeviceAdmin"
        private const val NOTIF_CHANNEL_ID = "koru_strict_mode_alerts"
        private const val NOTIF_CHANNEL_NAME = "Strict Mode Alerts"
        private const val NOTIF_ID_DEVICE_ADMIN_OFF = 4711

        /// Extra letto da MainActivity / GoRouter Flutter quando intercetta
        /// che l'utente sta cercando di disabilitare device admin con strict
        /// mode attivo. L'UI deve aprire il dialog del backdoor code.
        const val EXTRA_REQUIRE_BACKDOOR_CODE = "require_backdoor_code"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i(TAG, "Device admin enabled")
        // Se la mask era a 0 dopo un onDisabled precedente, la lasciamo a 0:
        // l'utente riabilita device admin e poi va ad accendere strict mode
        // dalla UI.
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.w(TAG, "Device admin DISABLED — strict mode hardening lost")
        // Coerenza UI: la mask resta nel store cifrato, ma le componenti
        // che si basano su device admin (block uninstall di Koru via
        // policy) non funzionano più. Per non confondere l'utente, mostriamo
        // la realtà: strict mode è effettivamente off, azzeriamo la mask.
        try {
            StrictModeStore.saveMask(context, 0)
            StrictModeEnforcer.invalidateCache()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reset mask on disable", e)
        }
        postDeviceAdminOffNotification(context)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        val mask = try {
            StrictModeStore.readMask(context)
        } catch (e: Exception) {
            // Fail-secure: se non riusciamo a leggere lo store, trattalo
            // come se fosse attivo.
            Log.e(TAG, "Failed to read mask in onDisableRequested", e)
            StrictModeStore.ALL_OPTIONS_ENABLED
        }

        if (mask != 0) {
            // Strict mode attivo: lanciamo MainActivity con il flag che dice
            // a Flutter di aprire la pagina backdoor in modalità "intercept".
            // L'utente vede il dialog del code prima ancora di completare
            // il disable nelle Settings.
            try {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                    )
                    putExtra(EXTRA_REQUIRE_BACKDOOR_CODE, true)
                }
                context.startActivity(launchIntent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch backdoor activity from onDisableRequested", e)
            }
            return "Strict mode is ACTIVE. Disabling Device Admin will turn it off. " +
                "You will be asked for your weekly backdoor code first."
        }

        return "Disabling Device Admin will turn off Strict Mode. Are you sure?"
    }

    /// Notifica persistente "Koru può essere disinstallato" — dopo il disable
    /// l'utente capisce immediatamente che la protezione non c'è più. Lo
    /// strict mode non può forzare il re-enable (non siamo Device Owner),
    /// ma la notifica è un deterrent UX.
    private fun postDeviceAdminOffNotification(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val existing = nm.getNotificationChannel(NOTIF_CHANNEL_ID)
                if (existing == null) {
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
                .setContentTitle("Device Admin disabilitato")
                .setContentText("Koru può ora essere disinstallato. Riabilita Device Admin per ripristinare strict mode.")
                .setStyle(
                    NotificationCompat.BigTextStyle().bigText(
                        "Device Admin di Koru è stato disabilitato. La protezione strict mode non è più attiva " +
                            "e Koru può essere disinstallato. Apri Koru → Settings → Strict mode per riabilitare.",
                    ),
                )
                .setOngoing(true)
                .setAutoCancel(false)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pi)
                .build()

            nm.notify(NOTIF_ID_DEVICE_ADMIN_OFF, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post device-admin-off notification", e)
        }
    }
}
