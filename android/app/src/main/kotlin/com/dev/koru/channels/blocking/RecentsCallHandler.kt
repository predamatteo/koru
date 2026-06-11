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
 * - `getOpenAppsCount` → Map {count: Int, seq: Long}. Fa una sweep
 *   incrementale UsageStats ([OpenAppsTracker.countWithSeq]), quindi gira
 *   off-main col pattern Thread + runOnUiThread di [AppInventoryCallHandler].
 *   Il seq monotono permette al Dart di scartare un pull stale che arrivi
 *   dopo un push più fresco.
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
                        val (count, seq) = OpenAppsTracker.countWithSeq(activity.applicationContext)
                        activity.runOnUiThread {
                            result.success(mapOf("count" to count, "seq" to seq))
                        }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("OPEN_APPS_COUNT_ERROR", e.message, null)
                        }
                    }
                }.start()
            }
            "resetOpenAppsCount" -> {
                // Off-main: resetAll prende lo stateLock del tracker, che una
                // sweep UsageStats in volo può tenere per decine di ms — mai
                // bloccare il platform thread.
                Thread {
                    try {
                        OpenAppsTracker.resetAll(activity.applicationContext)
                        activity.runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("OPEN_APPS_RESET_ERROR", e.message, null)
                        }
                    }
                }.start()
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
