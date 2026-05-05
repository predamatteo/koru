package com.dev.koru.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.dev.koru.MainActivity
import com.dev.koru.R
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeProfile
import com.dev.koru.overlay.BlockReason
import com.dev.koru.overlay.OverlayConfig
import org.json.JSONObject

class LockForegroundService : Service() {

    companion object {
        private const val TAG = "LockForegroundService"
        const val CHANNEL_ID = "koru_service"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "com.dev.koru.START_BLOCKING"
        const val ACTION_STOP = "com.dev.koru.STOP_BLOCKING"

        @Volatile
        var isRunning = false
            private set

        val quickBlockManager = QuickBlockManager()

        @Volatile
        private var currentLockRunnable: LockRunnable? = null

        fun triggerProfileReload() {
            Log.d(TAG, "triggerProfileReload called")
            currentLockRunnable?.let {
                com.dev.koru.db.NativeDatabase.close()
                it.needsReload = true
            }
        }
    }

    private var blockingThread: Thread? = null
    private var lockRunnable: LockRunnable? = null
    private var overlayManager: OverlayManager? = null
    private var reloadReceiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        quickBlockManager.attachContext(applicationContext)
        overlayManager = OverlayManager(applicationContext)
        overlayManager?.onReturnHome = {
            // Tap "Don't open" sull'overlay: l'utente vuole tornare alla
            // home del DISPOSITIVO (launcher di default), non a Koru.
            // performGoHome qui usa Intent(ACTION_MAIN, CATEGORY_HOME)
            // che il sistema dispatcha al default launcher — comportamento
            // corretto: se Koru non e' default, va sul launcher di stock.
            performGoHome()
            overlayManager?.dismiss()
        }

        // Listen for RELOAD_PROFILES broadcasts sent by ProfileMethodChannel.
        reloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == ProfileMethodChannel.ACTION_RELOAD_PROFILES) {
                    triggerProfileReload()
                }
            }
        }
        val filter = IntentFilter(ProfileMethodChannel.ACTION_RELOAD_PROFILES)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(reloadReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(reloadReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopBlocking()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            createNotification(),
                            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, createNotification())
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "startForeground failed", e)
                }
                startBlocking()
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        stopBlocking()
        quickBlockManager.stop()
        overlayManager?.destroy()
        overlayManager = null
        reloadReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        reloadReceiver = null
        super.onDestroy()
    }

    private fun setBlockingPersistenceFlag(active: Boolean) {
        getSharedPreferences("koru_prefs", MODE_PRIVATE)
            .edit()
            .putBoolean("blocking_was_active", active)
            .apply()
    }

    private fun startBlocking() {
        if (isRunning) return

        setBlockingPersistenceFlag(true)

        lockRunnable = LockRunnable(
            context = applicationContext,
            onBlock = { packageName, appLabel, profile, relation ->
                Log.d(TAG, "[BACKUP] Blocking $packageName (${profile.title})")
                val config = OverlayConfig.fromJsonString(relation?.overlayConfigJson)
                overlayManager?.show(
                    packageName = packageName,
                    appLabel = appLabel,
                    profileTitle = profile.title,
                    reason = BlockReason.APP_BLOCKED,
                    config = config,
                    profileEmoji = profile.emoji,
                )
                // Forziamo HOME anche dal foreground service: se siamo qui
                // l'AccessibilityService è morto, quindi non ci possiamo
                // più affidare al broadcast ACTION_GO_HOME (cadrebbe nel
                // vuoto). Il launch HOME via Intent funziona da qualunque
                // processo / device, indipendente da accessibility.
                performGoHome()
                sendBlockingEvent(true, packageName, profile)
            },
            onLimitBlock = { packageName, appLabel, limitMinutes, todayMs ->
                Log.d(TAG, "[BACKUP] Daily limit block $packageName (${todayMs / 60_000}/${limitMinutes}min)")
                // Stessa policy del path primario (KoruAccessibilityService):
                // strict ⇒ no "Open anyway"; non-strict ⇒ progressive friction
                // (countdown crescente, durate decrescenti). Coerenza tra
                // primary path e backup è critica: se divergono, l'utente
                // vede comportamenti diversi quando il servizio accessibility
                // muore vs è vivo.
                val isStrict = AppUsageLimitsStore.entryFor(
                    applicationContext, packageName,
                )?.strict ?: true
                val (cfg, policy) = OverlayPolicies.buildUsageLimitOverlay(
                    applicationContext, packageName, isStrict,
                )
                overlayManager?.show(
                    packageName = packageName,
                    appLabel = appLabel,
                    profileTitle = if (isStrict) "Daily limit · strict" else "Daily limit",
                    reason = BlockReason.USAGE_LIMIT,
                    config = cfg,
                    profileEmoji = "⏳", // ⏳
                    bypassPolicy = policy,
                )
                performGoHome()
            },
            onUnblock = {
                Log.d(TAG, "[BACKUP] Unblocking")
                overlayManager?.dismiss()
                sendBlockingEvent(false, "", null)
            },
        )

        currentLockRunnable = lockRunnable

        blockingThread = Thread(lockRunnable, "BlockingThread").apply {
            isDaemon = true
            start()
        }

        isRunning = true
        sendServiceStateEvent(true)
        Log.i(TAG, "Blocking service started")
    }

    private fun stopBlocking() {
        lockRunnable?.isRunning = false
        blockingThread?.interrupt()
        blockingThread = null
        lockRunnable = null
        currentLockRunnable = null
        overlayManager?.dismiss()
        isRunning = false
        setBlockingPersistenceFlag(false)
        sendServiceStateEvent(false)
        Log.i(TAG, "Blocking service stopped")
    }

    fun reloadProfiles() {
        lockRunnable?.reloadProfiles()
    }

    /**
     * Manda l'utente alla home screen senza dipendere dall'AccessibilityService.
     *
     * Path primario: `Intent(ACTION_MAIN, CATEGORY_HOME)` con `NEW_TASK` →
     * il sistema sa risolvere questo intent verso il default launcher
     * (o il chooser se non impostato). Funziona da qualunque processo,
     * non richiede privilegi speciali, indipendente dall'OEM.
     *
     * Fallback: il vecchio broadcast a `ACTION_GO_HOME` che l'AccessibilityService
     * captura per chiamare `GLOBAL_ACTION_HOME`. Se il path primario fallisce
     * per qualunque motivo (raro ma possibile su ROM custom), ci aggrappiamo
     * a quello.
     *
     * Perché questa modifica: se l'utente è qui via foreground service
     * di backup, è proprio perché l'AccessibilityService NON sta funzionando;
     * il broadcast cadrebbe nel vuoto e l'utente resterebbe dentro l'app
     * bloccata anche con l'overlay sopra.
     */
    private fun performGoHome() {
        try {
            val home = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(home)
        } catch (e: Exception) {
            Log.w(TAG, "Direct HOME intent failed, falling back to broadcast", e)
            sendBroadcast(
                Intent("com.dev.koru.ACTION_GO_HOME").apply { setPackage(packageName) },
            )
        }
    }

    private fun sendServiceStateEvent(running: Boolean) {
        val json = JSONObject().apply {
            put("type", "SERVICE_STATE")
            put("running", running)
        }
        ServiceEventChannel.sendEvent(json.toString())
    }

    private fun sendBlockingEvent(isBlocking: Boolean, packageName: String, profile: NativeProfile?) {
        val json = JSONObject().apply {
            put("type", "BLOCKING_STATE")
            put("isBlocking", isBlocking)
            put("packageName", packageName)
            put("profileId", profile?.id ?: -1)
            put("profileTitle", profile?.title ?: "")
        }
        ServiceEventChannel.sendEvent(json.toString())
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.koru_service_channel_title),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.koru_service_channel_description)
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun createNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val stopIntent = Intent(this, LockForegroundService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.koru_service_notification_title))
            .setContentText(getString(R.string.koru_service_notification_text))
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .build()
    }
}
