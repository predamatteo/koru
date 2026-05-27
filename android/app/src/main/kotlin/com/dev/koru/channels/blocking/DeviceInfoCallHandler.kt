package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: info di device/sistema lette dalla UI (livello batteria, stato di
 * carica, package del dialer e della fotocamera di default). Estratto da
 * `BlockingMethodChannel` (ARCH-09) coi suoi helper privati; comportamento e
 * wire-contract invariati.
 */
internal object DeviceInfoCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "getBatteryLevel",
        "isCharging",
        "getDefaultDialerPackage",
        "getDefaultCameraPackage",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getBatteryLevel" -> {
                val bm = activity.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                result.success(bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY))
            }
            "isCharging" -> {
                val bm = activity.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                result.success(bm.isCharging)
            }
            "getDefaultDialerPackage" -> {
                result.success(resolveDefaultDialer(activity))
            }
            "getDefaultCameraPackage" -> {
                result.success(resolveDefaultCamera(activity))
            }
        }
    }

    /// Risolve il package del dialer di sistema (telecom + fallback su
    /// Intent.ACTION_DIAL se TelecomManager non disponibile).
    private fun resolveDefaultDialer(context: Context): String? {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val tm = context.getSystemService(Context.TELECOM_SERVICE)
                    as? android.telecom.TelecomManager
                val pkg = tm?.defaultDialerPackage
                if (!pkg.isNullOrBlank()) return pkg
            }
        } catch (_: Exception) {}
        val intent = Intent(Intent.ACTION_DIAL)
        val ri = context.packageManager.resolveActivity(intent, 0)
        return ri?.activityInfo?.packageName
    }

    /// Risolve l'app fotocamera di default (IMAGE_CAPTURE).
    private fun resolveDefaultCamera(context: Context): String? {
        val intent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)
        val ri = context.packageManager.resolveActivity(intent, 0)
        return ri?.activityInfo?.packageName
    }
}
