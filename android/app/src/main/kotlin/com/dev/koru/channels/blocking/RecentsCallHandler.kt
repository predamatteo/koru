package com.dev.koru.channels.blocking

import android.accessibilityservice.AccessibilityService
import android.app.Activity
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.LauncherRecentsGate
import com.dev.koru.service.OpenAppsTracker
import com.dev.koru.strictmode.StrictModeEnforcer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: contatore "schede aperte in background" del launcher + apertura
 * delle recents di sistema via AccessibilityService.
 *
 * - `getOpenAppsCount` → Int. Fa una sweep incrementale UsageStats
 *   ([OpenAppsTracker.count]), quindi gira off-main col pattern
 *   Thread + runOnUiThread di [AppInventoryCallHandler].
 * - `resetOpenAppsCount` → true. Long-press sull'icona del launcher.
 * - `openSystemRecents` → Boolean (false = non possibile). Emette
 *   l'allow-token sul [LauncherRecentsGate] PRIMA di
 *   GLOBAL_ACTION_RECENTS, così il gate non richiude la schermata che
 *   l'utente ha chiesto esplicitamente.
 */
internal object RecentsCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "getOpenAppsCount",
        "resetOpenAppsCount",
        "openSystemRecents",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getOpenAppsCount" -> {
                Thread {
                    try {
                        val count = OpenAppsTracker.count(activity.applicationContext)
                        activity.runOnUiThread { result.success(count) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("OPEN_APPS_COUNT_ERROR", e.message, null)
                        }
                    }
                }.start()
            }
            "resetOpenAppsCount" -> {
                OpenAppsTracker.resetAll(activity.applicationContext)
                result.success(true)
            }
            "openSystemRecents" -> {
                // Difesa in profondità: con BLOCK_RECENT_APPS attivo il tap
                // non deve aprire una schermata che lo strict richiuderebbe
                // subito (l'icona lato Dart è già disabilitata, ma il check
                // no-IO qui chiude il race). NB: lettura della cache
                // @Volatile, mai Keystore sul platform thread.
                if (StrictModeEnforcer.isRecentsBlockedCached()) {
                    result.success(false)
                    return
                }
                val service = KoruAccessibilityService.instance
                if (service == null) {
                    // Servizio accessibilità spento: GLOBAL_ACTION_RECENTS
                    // impossibile (lato Dart l'icona è nascosta in questo
                    // stato, ma il channel resta difensivo).
                    result.success(false)
                    return
                }
                LauncherRecentsGate.noteAllowRequest()
                val ok = try {
                    service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS)
                } catch (_: Exception) {
                    false
                }
                result.success(ok)
            }
        }
    }
}
