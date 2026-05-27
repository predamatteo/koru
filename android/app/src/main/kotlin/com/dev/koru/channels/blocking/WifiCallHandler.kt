package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: lettura dell'SSID WiFi corrente (usato dai profili WiFi-scoped).
 * Estratto da `BlockingMethodChannel` (ARCH-09); comportamento e wire-contract
 * invariati.
 */
internal object WifiCallHandler : BlockingCallHandler {

    override val methods = setOf("getCurrentWifiSsid")

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getCurrentWifiSsid" -> {
                result.success(getCurrentWifiSsid(activity))
            }
        }
    }

    /// Legge il SSID della rete WiFi corrente. Su Android 10+ richiede
    /// ACCESS_FINE_LOCATION; se permesso non concesso ritorna null o
    /// "<unknown ssid>". L'UI gestisce la degradazione gentilmente.
    private fun getCurrentWifiSsid(context: Context): String? {
        return try {
            val wm = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
            val info = wm?.connectionInfo ?: return null
            val ssid = info.ssid
            if (ssid == null || ssid == "<unknown ssid>") return null
            // SSID è restituito wrapped tra virgolette.
            if (ssid.length >= 2 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid.substring(1, ssid.length - 1)
            } else {
                ssid
            }
        } catch (_: Exception) {
            null
        }
    }
}
