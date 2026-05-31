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

    private const val TAG = "KoruAppActions"

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
                android.util.Log.i(
                    TAG,
                    "uninstallApp($pkg): mask=$mask blockUninstallBit=" +
                        "${mask and StrictModeStore.BLOCK_UNINSTALLING}",
                )
                if (mask and StrictModeStore.BLOCK_UNINSTALLING != 0) {
                    result.error(
                        "BLOCK_UNINSTALLING",
                        "Uninstalling is blocked while strict mode is active.",
                        null,
                    )
                    return
                }
                // Lancio robusto: alcuni ROM OEM (OxygenOS/ColorOS su OnePlus,
                // MIUI, …) NON risolvono ACTION_DELETE con uri `package:` ma
                // risolvono ACTION_UNINSTALL_PACKAGE (o viceversa). Con un solo
                // intent, su quei device startActivity lancia
                // ActivityNotFoundException e l'utente tappa "Disinstalla" senza
                // che succeda NULLA. `launchUninstall` prova entrambi gli intent
                // e ritorna false solo se nessuno è gestito → il chiamante
                // Flutter mostra un feedback invece del silenzio.
                if (launchUninstall(activity, pkg)) {
                    result.success(true)
                } else {
                    result.error(
                        "UNINSTALL_FAILED",
                        "No activity on this device handled the uninstall request for $pkg.",
                        null,
                    )
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

    /// Lancia la finestra di disinstallazione di sistema per [pkg] provando in
    /// sequenza ACTION_DELETE e ACTION_UNINSTALL_PACKAGE (entrambi con uri
    /// `package:`). ACTION_DELETE è tentato per PRIMO perché è quello che già
    /// funzionava sugli altri device (comportamento invariato lì); il fallback
    /// copre i ROM OEM che risolvono solo ACTION_UNINSTALL_PACKAGE. Ritorna true
    /// al primo intent effettivamente avviato; false se NESSUNO è gestito dal
    /// device. Logga ogni tentativo per la diagnostica via
    /// `adb logcat -s KoruAppActions`.
    ///
    /// `@Suppress("DEPRECATION")`: ACTION_UNINSTALL_PACKAGE è deprecato in
    /// favore di PackageInstaller, ma qui è SOLO un fallback dietro
    /// ACTION_DELETE (non deprecato, tentato per primo) per coprire i ROM OEM
    /// che risolvono l'uno e non l'altro. Migrare a PackageInstaller cambierebbe
    /// la UX (nessun dialog di sistema) e non serve allo scopo.
    @Suppress("DEPRECATION")
    private fun launchUninstall(activity: Activity, pkg: String): Boolean {
        val uri = android.net.Uri.parse("package:$pkg")
        val candidates = listOf(
            Intent(Intent.ACTION_DELETE, uri),
            Intent(Intent.ACTION_UNINSTALL_PACKAGE, uri),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                activity.startActivity(intent)
                android.util.Log.i(TAG, "Uninstall launched via ${intent.action} for $pkg")
                return true
            } catch (e: android.content.ActivityNotFoundException) {
                android.util.Log.w(TAG, "${intent.action} not handled for $pkg: ${e.message}")
            } catch (e: Exception) {
                android.util.Log.w(TAG, "${intent.action} failed for $pkg: ${e.message}")
            }
        }
        return false
    }
}
