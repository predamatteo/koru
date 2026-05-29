package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Intent
import com.dev.koru.strictmode.StrictModeStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: azioni dirette su una singola app (launch, uninstall, app-info).
 * Estratto da `BlockingMethodChannel` (ARCH-09); comportamento e wire-contract
 * invariati — incluso il guard strict-mode su `uninstallApp`. Quando
 * BLOCK_UNINSTALLING è attivo rifiutiamo QUALSIASI disinstallazione (non solo
 * Koru) con `result.error("BLOCK_UNINSTALLING", …)`: lo StrictModeEnforcer
 * (a livello accessibility) rimanderebbe comunque indietro il package installer
 * per ogni app — la finestra di sistema lampeggia e sparisce, dal punto di vista
 * utente "non succede niente". Rifiutando qui, PRIMA di lanciare l'intent,
 * evitiamo il flash e diamo al chiamante Flutter un errore esplicito su cui
 * mostrare un alert ("la modalità rigida blocca la disinstallazione").
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
                // Guard strict mode: con BLOCK_UNINSTALLING attivo lo
                // StrictModeEnforcer rimanda comunque indietro il package
                // installer per QUALSIASI app. Rifiutiamo qui prima di
                // lanciare l'intent (no flash della finestra di sistema) e
                // restituiamo un errore esplicito così il chiamante Flutter
                // può mostrare un alert invece di lasciare l'utente con
                // "non succede niente". Vale sia per Koru stessa (non puoi
                // rimuovere il blocco per scappare dall'impegno) sia per le
                // altre app (allineato all'enforcer, che le bloccherebbe).
                val mask = StrictModeStore.readMask(activity)
                if (mask and StrictModeStore.BLOCK_UNINSTALLING != 0) {
                    result.error(
                        "BLOCK_UNINSTALLING",
                        "Uninstalling is blocked while strict mode is active.",
                        null,
                    )
                    return
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
