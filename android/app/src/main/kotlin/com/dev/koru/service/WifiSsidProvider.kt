package com.dev.koru.service

import android.content.Context

/**
 * SSID WiFi corrente, condiviso da ENTRAMBI i path di enforcement
 * ([KoruAccessibilityService] event-driven e [LockRunnable] backup polling).
 *
 * Esiste come helper UNICO di proposito: il vincolo wifi dei profili era
 * applicato solo nel path accessibility, e copiarne la lettura nel backup
 * avrebbe ricreato esattamente la parità-per-copia che il refactor del
 * BlockPolicyEvaluator elimina (CR-03). Un solo punto di lettura ⇒ una sola
 * semantica di normalizzazione del SSID.
 *
 * Ritorna `null` se non connessi o se manca il permesso location (su Android
 * recenti `WifiManager.connectionInfo.ssid` torna `<unknown ssid>` senza
 * ACCESS_FINE_LOCATION). I chiamanti trattano `null` come "nessun match" →
 * profilo wifi-vincolato inattivo (fail-secure).
 */
fun currentWifiSsid(context: Context): String? {
    return try {
        val wm = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
        val info = wm?.connectionInfo ?: return null
        val ssid = info.ssid
        if (ssid == null || ssid == "<unknown ssid>") return null
        // Il SSID arriva quotato (`"MyWifi"`); rimuovi le virgolette esterne
        // per matchare i valori salvati nel DB (non quotati).
        if (ssid.length >= 2 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
            ssid.substring(1, ssid.length - 1)
        } else {
            ssid
        }
    } catch (_: Exception) {
        null
    }
}
