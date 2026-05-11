package com.dev.koru.notification

import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Listener delle notifiche di sistema. Quando l'utente ha configurato
 * un pkg come "silenziato" in Koru, questa classe cancella la
 * notifica appena arriva (rimuove dalla status bar + shade).
 *
 * NON cancella messaggi già letti, non li archivia, non legge il
 * contenuto — semplice dismiss. Per MVP è sufficiente a tagliare
 * gli interrupt visivi/audio da app distraenti.
 *
 * Rebind pattern: su alcuni OEM aggressivi (e dopo update di
 * sistema/app) il NotificationManagerService può disconnettere il
 * listener senza ribindarlo automaticamente. `onListenerDisconnected`
 * chiama esplicitamente `requestRebind` per ripristinare la
 * connessione → niente buco silenzioso di silenziamenti.
 */
class KoruNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "KoruNotifListener"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener connected to NotificationManager")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Listener disconnected, requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(ComponentName(this, KoruNotificationListenerService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "requestRebind failed: ${e.message}")
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        val store = NotificationFilterStore
        if (!store.isSilenced(applicationContext, pkg)) return
        try {
            cancelNotification(sbn.key)
            Log.d(TAG, "Silenced notification from $pkg")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cancel notification: ${e.message}")
        }
    }
}
