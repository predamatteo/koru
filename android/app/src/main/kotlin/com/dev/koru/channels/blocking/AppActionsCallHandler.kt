package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Intent
import com.dev.koru.strictmode.StrictModeStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: azioni dirette su una singola app (launch, uninstall, app-info).
 * Estratto da `BlockingMethodChannel` (ARCH-09); comportamento e wire-contract
 * invariati — incluso il guard strict-mode su `uninstallApp` (defense in depth:
 * rifiuta la disinstallazione di Koru se BLOCK_UNINSTALLING è attivo).
 */
internal object AppActionsCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "launchApp",
        "uninstallApp",
        "openAppInfo",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "launchApp" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                val intent = activity.packageManager.getLaunchIntentForPackage(pkg)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "uninstallApp" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                // Guard strict mode: se l'utente sta cercando di
                // disinstallare Koru stessa mentre BLOCK_UNINSTALLING
                // è attivo, blocchiamo l'intent prima ancora di
                // arrivare al package installer (defense in depth:
                // anche se StrictModeEnforcer dovesse missarlo,
                // questo livello rifiuta).
                if (pkg == activity.packageName) {
                    val mask = StrictModeStore.readMask(activity)
                    if (mask and StrictModeStore.BLOCK_UNINSTALLING != 0) {
                        result.error(
                            "BLOCK_UNINSTALLING",
                            "Cannot uninstall Koru while strict mode protects uninstalling.",
                            null,
                        )
                        return
                    }
                }
                try {
                    val intent = Intent(Intent.ACTION_DELETE).apply {
                        data = android.net.Uri.parse("package:$pkg")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNINSTALL_FAILED", e.message, null)
                }
            }
            "openAppInfo" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                try {
                    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.parse("package:$pkg")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("APP_INFO_FAILED", e.message, null)
                }
            }
        }
    }
}
