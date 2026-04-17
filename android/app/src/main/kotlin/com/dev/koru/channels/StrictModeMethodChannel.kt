package com.dev.koru.channels

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import com.dev.koru.db.NativeDatabase
import com.dev.koru.strictmode.BackdoorCodeGenerator
import com.dev.koru.strictmode.KoruDeviceAdminReceiver
import com.dev.koru.strictmode.StrictModeEnforcer
import com.dev.koru.strictmode.StrictModeStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object StrictModeMethodChannel {
    private const val TAG = "StrictModeCh"
    private const val CHANNEL = "com.koru/strict_mode"

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableDeviceAdmin" -> {
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component)
                            putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "Koru needs Device Admin to lock Settings/Recent/Uninstall while Strict Mode is active."
                            )
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    }
                    "disableDeviceAdmin" -> {
                        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        if (dpm.isAdminActive(component)) dpm.removeActiveAdmin(component)
                        result.success(true)
                    }
                    "isDeviceAdminActive" -> {
                        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        result.success(dpm.isAdminActive(component))
                    }
                    "setStrictModeOptions" -> {
                        val mask = call.argument<Int>("mask") ?: 0
                        Log.i(TAG, "setStrictModeOptions: $mask")
                        StrictModeStore.saveMask(activity, mask)
                        StrictModeEnforcer.invalidateCache()
                        result.success(null)
                    }
                    "getStrictModeOptions" -> {
                        result.success(StrictModeStore.readMask(activity))
                    }
                    "generateBackdoorCode" -> {
                        result.success(BackdoorCodeGenerator.generateCurrentCode(activity))
                    }
                    "validateBackdoorCode" -> {
                        val code = call.argument<String>("code") ?: ""
                        val valid = BackdoorCodeGenerator.validateCode(activity, code)
                        if (valid) {
                            try {
                                val db = NativeDatabase.open(activity)
                                db.execSQL(
                                    "INSERT OR IGNORE INTO used_backdoor_codes (code, used_at) VALUES (?, ?)",
                                    arrayOf(code, System.currentTimeMillis())
                                )
                            } catch (_: Exception) {}
                        }
                        result.success(valid)
                    }
                    "performEmergencyUnblock" -> {
                        StrictModeStore.saveMask(activity, 0)
                        StrictModeEnforcer.invalidateCache()
                        try {
                            val db = NativeDatabase.open(activity)
                            db.execSQL(
                                "INSERT INTO emergency_unblocks (timestamp) VALUES (?)",
                                arrayOf(System.currentTimeMillis())
                            )
                        } catch (_: Exception) {}
                        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val component = ComponentName(activity, KoruDeviceAdminReceiver::class.java)
                        if (dpm.isAdminActive(component)) dpm.removeActiveAdmin(component)
                        result.success(true)
                    }
                    "isStrictModeActive" -> {
                        result.success(StrictModeStore.readMask(activity) != 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
