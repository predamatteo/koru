package com.dev.koru.channels.blocking

import android.app.Activity
import com.dev.koru.service.LockForegroundService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: quick-block e Pomodoro (focus a tempo). Estratto da
 * `BlockingMethodChannel` (ARCH-09); comportamento e wire-contract invariati.
 *
 * Il context va attaccato anche se il service non è mai stato istanziato: serve
 * per persistere lo snapshot letto dal processo `:accessibility`.
 */
internal object QuickBlockCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "startQuickBlock",
        "stopQuickBlock",
        "startPomodoro",
        "stopPomodoro",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "startQuickBlock" -> {
                val durationMs = call.longArg("durationMs")
                val whitelist = (call.argument<List<String>>("whitelist") ?: emptyList())
                    .toSet()
                // Il context va attaccato anche se il service non è
                // mai stato istanziato: serve per persistere lo
                // snapshot letto dal processo :accessibility.
                LockForegroundService.quickBlockManager.attachContext(activity.applicationContext)
                LockForegroundService.quickBlockManager.startQuickBlock(
                    durationMs,
                    whitelist,
                )
                result.success(true)
            }
            "stopQuickBlock" -> {
                LockForegroundService.quickBlockManager.stop()
                result.success(true)
            }
            "startPomodoro" -> {
                val workMs = call.longArg("workMs")
                val breakMs = call.longArg("breakMs")
                val cycles = call.argument<Int>("cycles") ?: 4
                val whitelist = (call.argument<List<String>>("whitelist") ?: emptyList())
                    .toSet()
                LockForegroundService.quickBlockManager.attachContext(activity.applicationContext)
                LockForegroundService.quickBlockManager.startPomodoro(
                    workMs,
                    breakMs,
                    cycles,
                    whitelist,
                )
                result.success(true)
            }
            "stopPomodoro" -> {
                LockForegroundService.quickBlockManager.stop()
                result.success(true)
            }
        }
    }
}
