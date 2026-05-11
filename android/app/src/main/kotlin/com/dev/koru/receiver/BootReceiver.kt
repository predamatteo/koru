package com.dev.koru.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat
import com.dev.koru.service.LockForegroundService

/**
 * Riavvia il blocking service al boot se era attivo prima del reboot.
 * Flag persistito in SharedPreferences `koru_prefs` → key `blocking_was_active`.
 *
 * Su Android 14+ (API 34) il foreground service di tipo `specialUse` non
 * può essere avviato direttamente da BOOT_COMPLETED senza eccezioni
 * (ForegroundServiceStartNotAllowedException). In quel caso ignoriamo
 * silenziosamente: il service riparte comunque al primo onResume di
 * MainActivity tramite `ensureBackupBlockingServiceStarted()`.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            Log.i("KoruBoot", "Boot action=${intent.action}, checking blocking state")
            val prefs = context.getSharedPreferences("koru_prefs", Context.MODE_PRIVATE)
            if (prefs.getBoolean("blocking_was_active", false)) {
                val serviceIntent = Intent(context, LockForegroundService::class.java).apply {
                    action = LockForegroundService.ACTION_START
                }
                try {
                    ContextCompat.startForegroundService(context, serviceIntent)
                    Log.i("KoruBoot", "Blocking service restarted after boot")
                } catch (e: Exception) {
                    // ForegroundServiceStartNotAllowedException su Android 14:
                    // fallback silenzioso, il service partirà al primo unlock
                    // via MainActivity.onResume → ensureBackupBlockingServiceStarted().
                    Log.w("KoruBoot", "Foreground service start blocked from boot: ${e.message}")
                }
            }
        }
    }
}
