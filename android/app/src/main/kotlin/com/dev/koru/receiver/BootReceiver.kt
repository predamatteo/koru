package com.dev.koru.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.dev.koru.service.LockForegroundService

/**
 * Riavvia il blocking service al boot se era attivo prima del reboot.
 * Flag persistito in SharedPreferences `koru_prefs` → key `blocking_was_active`.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.i("BootReceiver", "Boot completed, checking blocking state")
            val prefs = context.getSharedPreferences("koru_prefs", Context.MODE_PRIVATE)
            if (prefs.getBoolean("blocking_was_active", false)) {
                val serviceIntent = Intent(context, LockForegroundService::class.java).apply {
                    action = LockForegroundService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.i("BootReceiver", "Blocking service restarted after boot")
            }
        }
    }
}
