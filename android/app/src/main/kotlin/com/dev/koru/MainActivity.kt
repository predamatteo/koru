package com.dev.koru

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dev.koru.channels.BlockingMethodChannel
import com.dev.koru.channels.NavigationMethodChannel
import com.dev.koru.channels.PackageEventsReceiver
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.StrictModeMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.channels.PermissionMethodChannel
import com.dev.koru.db.NativeDatabase
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.LockForegroundService

class MainActivity : FlutterActivity() {
    private var packageEventsReceiver: PackageEventsReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Defense-in-depth: assicura che la foreground service di
        // backup sia viva se l'utente ha già configurato qualcosa che
        // richiede blocking. Cosi' anche se l'AccessibilityService
        // viene killata da OEM aggressivi (ColorOS/MIUI/Samsung) il
        // polling loop continua a far rispettare profili e daily limits.
        // Idempotente: niente succede se è già running.
        ensureBackupBlockingServiceStarted()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BlockingMethodChannel.register(flutterEngine, this)
        ProfileMethodChannel.register(flutterEngine, this)
        StrictModeMethodChannel.register(flutterEngine, this)
        ServiceEventChannel.register(flutterEngine)
        PermissionMethodChannel.register(flutterEngine, this)
        NavigationMethodChannel.register(flutterEngine)
    }

    /**
     * Avvia [LockForegroundService] se l'utente ha (a) almeno un daily limit
     * configurato, (b) almeno un profilo abilitato, oppure (c) il flag
     * `blocking_was_active` è true (il servizio era già in esecuzione in
     * una sessione precedente — succede dopo reboot se BootReceiver non
     * fires, oppure se il sistema killa il processo).
     *
     * Il check (a) è una read di file istantanea; il check (b) è una
     * query DB, quindi parte su un thread di background. Se serve, il
     * service viene avviato sul main thread (requisito di
     * `startForegroundService`).
     */
    private fun ensureBackupBlockingServiceStarted() {
        if (LockForegroundService.isRunning) return

        val prefs = getSharedPreferences("koru_prefs", MODE_PRIVATE)
        val wasActive = prefs.getBoolean("blocking_was_active", false)
        val hasLimits = AppUsageLimitsStore.read(applicationContext).isNotEmpty()

        if (wasActive || hasLimits) {
            startBackupBlockingServiceNow()
            return
        }

        // Profili: query DB su thread di background per non bloccare onCreate.
        Thread {
            val hasProfiles = try {
                NativeDatabase.getEnabledProfiles(applicationContext).isNotEmpty()
            } catch (_: Exception) { false }
            if (hasProfiles) {
                Handler(Looper.getMainLooper()).post { startBackupBlockingServiceNow() }
            }
        }.start()
    }

    private fun startBackupBlockingServiceNow() {
        if (LockForegroundService.isRunning) return
        try {
            val intent = Intent(this, LockForegroundService::class.java).apply {
                action = LockForegroundService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.i("MainActivity", "Auto-started LockForegroundService (backup)")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to auto-start LockForegroundService", e)
        }
    }

    /**
     * Registriamo il receiver di PACKAGE_ADDED/REMOVED/REPLACED solo mentre
     * l'activity è visibile (onStart/onStop): l'unico consumer è la UI della
     * lista app. Android 8+ non consente la dichiarazione nel Manifest per
     * questi broadcast, quindi la registrazione dev'essere dinamica.
     */
    override fun onStart() {
        super.onStart()
        if (packageEventsReceiver == null) {
            val receiver = PackageEventsReceiver()
            registerReceiver(receiver, PackageEventsReceiver.newFilter())
            packageEventsReceiver = receiver
        }
    }

    override fun onStop() {
        super.onStop()
        packageEventsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // già deregistrato — safe da ignorare
            }
        }
        packageEventsReceiver = null
    }

    /**
     * Route iniziale Flutter: `/launcher` SOLO quando l'intent di lancio è
     * HOME E Koru è effettivamente il launcher di default del sistema.
     * Altrimenti (aperta da drawer, task switcher, o HOME intent residuo
     * dopo che l'utente ha cambiato default launcher) partiamo da `/` →
     * GoRouter redirige a `/home`.
     */
    override fun getInitialRoute(): String? {
        val current = intent ?: return super.getInitialRoute()
        return if (isHomeIntent(current) && isDefaultLauncher()) {
            "/launcher"
        } else {
            super.getInitialRoute()
        }
    }

    /**
     * MainActivity è `singleTask`: un nuovo intent non ricrea l'activity,
     * fa partire onNewIntent. Due casi:
     * - HOME intent + Koru default launcher → naviga Flutter a `/launcher`.
     * - Qualsiasi altro intent (drawer / task switcher / HOME senza essere
     *   default) → se Flutter è parcheggiato su `/launcher` (residuo di
     *   una sessione in cui Koru era default), uscine verso `/home`.
     *
     * Eccezione: se l'HOME intent è stato triggerato dal blocking engine
     * (KoruAccessibilityService quando blocca un'app o StrictModeEnforcer
     * quando blocca settings/recents/etc.), [KoruAccessibilityService.
     * suppressLauncherNavigationUntilMs] ha settato una finestra di
     * soppressione: in quel caso non navighiamo, l'utente conserva la
     * pagina su cui si trovava.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val now = System.currentTimeMillis()
        if (now < KoruAccessibilityService.suppressLauncherNavigationUntilMs) {
            // Reset del flag: la soppressione vale solo per il singolo
            // intent appena ricevuto, non per quelli successivi.
            KoruAccessibilityService.suppressLauncherNavigationUntilMs = 0L
            return
        }
        if (isHomeIntent(intent) && isDefaultLauncher()) {
            NavigationMethodChannel.goToLauncher()
        } else {
            NavigationMethodChannel.goToHomeIfOnLauncher()
        }
    }

    private fun isHomeIntent(intent: Intent): Boolean =
        intent.action == Intent.ACTION_MAIN &&
            intent.categories?.contains(Intent.CATEGORY_HOME) == true

    private fun isDefaultLauncher(): Boolean {
        val probe = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val resolve = packageManager.resolveActivity(probe, 0)
        return resolve?.activityInfo?.packageName == packageName
    }
}
