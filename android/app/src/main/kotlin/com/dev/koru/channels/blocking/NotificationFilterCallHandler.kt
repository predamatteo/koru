package com.dev.koru.channels.blocking

import android.app.Activity
import android.os.Build
import android.content.Intent
import com.dev.koru.notification.NotificationFilterStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: filtro notifiche (set di package silenziati) + stato/aper­tura del
 * permesso "Notification access". Estratto da `BlockingMethodChannel` (ARCH-09)
 * col suo helper di apertura settings; comportamento e wire-contract invariati,
 * con l'unica eccezione INTENZIONALE di `setSilencedPackages` (CR-09, sotto).
 */
internal object NotificationFilterCallHandler : BlockingCallHandler {

    private const val LISTENER_COMPONENT =
        "com.dev.koru.notification.KoruNotificationListenerService"

    override val methods = setOf(
        "getSilencedPackages",
        "setSilencedPackages",
        "isNotificationAccessGranted",
        "openNotificationAccessSettings",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getSilencedPackages" -> {
                result.success(
                    NotificationFilterStore.read(activity.applicationContext).toList()
                )
            }
            "setSilencedPackages" -> {
                val list = call.argument<List<String>>("packages") ?: emptyList()
                // CR-09: `save` ritorna ora un Boolean (scrittura atomica). Prima
                // era `result.success(true)` incondizionato → il Dart non poteva
                // sapere che il salvataggio del filtro era fallito. Propaghiamo
                // il vero risultato.
                val saved = NotificationFilterStore.save(activity.applicationContext, list.toSet())
                result.success(saved)
            }
            "isNotificationAccessGranted" -> {
                val flat = android.provider.Settings.Secure.getString(
                    activity.contentResolver,
                    "enabled_notification_listeners",
                ) ?: ""
                val expected = "${activity.packageName}/$LISTENER_COMPONENT"
                result.success(flat.contains(expected))
            }
            "openNotificationAccessSettings" -> {
                val ok = openNotificationAccessSettings(activity)
                result.success(ok)
            }
        }
    }

    /// Apre le Settings di "Notification access" con fallback robusto:
    /// prima prova il deep-link diretto al component di Koru
    /// (ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS, API 30+), poi
    /// la action generica, poi Settings root. Ciascun tentativo è
    /// wrapped in try/catch per evitare crash su device dove l'intent
    /// non è disponibile o è bloccato da policy OEM.
    private fun openNotificationAccessSettings(activity: Activity): Boolean {
        val component = android.content.ComponentName(
            activity.packageName,
            LISTENER_COMPONENT,
        )

        // Tentativo 1: deep-link al detail (Android 11+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(
                    android.provider.Settings
                        .ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS,
                )
                    .putExtra(
                        android.provider.Settings
                            .EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        component.flattenToString(),
                    )
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // Tentativo 2: lista generica di notification listeners.
        try {
            val intent = Intent(
                android.provider.Settings
                    .ACTION_NOTIFICATION_LISTENER_SETTINGS,
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}

        // Fallback finale: Settings root.
        try {
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}
        return false
    }
}
