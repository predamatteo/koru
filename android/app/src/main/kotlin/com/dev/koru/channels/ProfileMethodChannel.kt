package com.dev.koru.channels

import android.app.Activity
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object ProfileMethodChannel {
    private const val TAG = "ProfileMethodChannel"
    private const val CHANNEL = "com.koru/profiles"
    const val ACTION_RELOAD_PROFILES = "com.dev.koru.ACTION_RELOAD_PROFILES"

    private var activityRef: Activity? = null

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        activityRef = activity
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "notifyProfileChanged" -> {
                        val profileId = call.argument<Int>("profileId") ?: -1
                        Log.d(TAG, "Profile changed: $profileId")
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "notifyProfileToggled" -> {
                        val profileId = call.argument<Int>("profileId") ?: -1
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        Log.d(TAG, "Profile toggled: $profileId -> $enabled")
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "setProfilePaused" -> {
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "syncAll" -> {
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun reloadServiceProfiles() {
        val ctx = activityRef ?: return
        try {
            val intent = Intent(ACTION_RELOAD_PROFILES).apply {
                setPackage(ctx.packageName)
            }
            ctx.sendBroadcast(intent)
            Log.d(TAG, "Sent RELOAD_PROFILES broadcast")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send reload broadcast", e)
        }
    }
}
