package com.dev.koru.channels

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.dev.koru.service.OpenAppsTracker
import org.json.JSONObject

/**
 * Ascolta PACKAGE_ADDED / PACKAGE_REMOVED / PACKAGE_REPLACED e notifica
 * Flutter via [ServiceEventChannel] così il provider Dart della lista app
 * installate si invalida e ricarica la lista dal PackageManager.
 *
 * Su Android 8+ questi broadcast NON possono essere dichiarati nel Manifest
 * (whitelist: https://developer.android.com/guide/components/broadcast-exceptions),
 * vanno registrati dinamicamente a runtime — cosa che ha senso qui perché
 * il refresh della lista serve solo mentre la UI è viva.
 */
class PackageEventsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        // Early-return su packageName vuoto: alcuni broadcast malformati
        // (o intent injection da componenti di sistema senza data) arrivano
        // senza scheme-specific-part, e propagarli nel channel Flutter
        // avrebbe come effetto di invalidare la lista installed apps senza
        // motivo, scatenando un refresh fullinde inutile su PackageManager.
        val packageName = intent.data?.schemeSpecificPart ?: return
        if (packageName.isEmpty()) return

        // PACKAGE_REPLACED emette ANCHE un PACKAGE_REMOVED con EXTRA_REPLACING=true
        // seguito da PACKAGE_ADDED con EXTRA_REPLACING=true. Per evitare 3 eventi
        // a fronte di un singolo update, ignoriamo i REMOVED/ADDED "replacing"
        // — il PACKAGE_REPLACED finale copre il caso.
        val replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
        if (replacing && action != Intent.ACTION_PACKAGE_REPLACED) return

        val kind = when (action) {
            Intent.ACTION_PACKAGE_ADDED -> "added"
            Intent.ACTION_PACKAGE_REMOVED -> "removed"
            Intent.ACTION_PACKAGE_REPLACED -> "replaced"
            else -> return
        }
        // Prune immediato del contatore "schede aperte" su uninstall
        // (best-effort: il receiver vive solo con l'Activity visibile;
        // il prune autoritativo resta quello in OpenAppsTracker.refresh).
        OpenAppsTracker.onPackageChanged(packageName, removed = kind == "removed")
        val payload = JSONObject()
            .put("type", "PACKAGE_CHANGED")
            .put("kind", kind)
            .put("packageName", packageName)
        ServiceEventChannel.sendEvent(payload.toString())
    }

    companion object {
        fun newFilter(): IntentFilter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            // I broadcast PACKAGE_* richiedono il data scheme "package".
            addDataScheme("package")
        }
    }
}
