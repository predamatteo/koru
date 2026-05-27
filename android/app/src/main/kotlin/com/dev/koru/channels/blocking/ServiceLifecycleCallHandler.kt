package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Intent
import android.os.Build
import com.dev.koru.service.LockForegroundService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: ciclo di vita della [LockForegroundService] di backup
 * (start/stop/isRunning). Estratto da `BlockingMethodChannel` (ARCH-09);
 * comportamento e wire-contract invariati.
 */
internal object ServiceLifecycleCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "startBlockingService",
        "stopBlockingService",
        "isBlockingServiceRunning",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "startBlockingService" -> {
                try {
                    val intent = Intent(activity, LockForegroundService::class.java).apply {
                        action = LockForegroundService.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        activity.startForegroundService(intent)
                    } else {
                        activity.startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_START_FAILED", e.message, null)
                }
            }
            "stopBlockingService" -> {
                val intent = Intent(activity, LockForegroundService::class.java).apply {
                    action = LockForegroundService.ACTION_STOP
                }
                activity.startService(intent)
                result.success(true)
            }
            "isBlockingServiceRunning" -> result.success(LockForegroundService.isRunning)
        }
    }
}
