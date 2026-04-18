package com.dev.koru.notification

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
 */
class KoruNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "KoruNotifListener"
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
