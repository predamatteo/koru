package com.dev.koru

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dev.koru.channels.BatteryEventChannel
import com.dev.koru.channels.BlackBoxMethodChannel
import com.dev.koru.channels.BlockingMethodChannel
import com.dev.koru.channels.NavigationMethodChannel
import com.dev.koru.channels.PackageEventsReceiver
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.StrictModeMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.channels.PermissionMethodChannel
import com.dev.koru.db.NativeDatabase
import com.dev.koru.diagnostics.BlackBox
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.LockForegroundService
import com.dev.koru.strictmode.KoruDeviceAdminReceiver

class MainActivity : FlutterActivity() {
    private var packageEventsReceiver: PackageEventsReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(
            "MainActivity",
            "onCreate: action=${intent?.action} isHome=${intent?.let { isHomeIntent(it) }} " +
                "suppressUntil=${KoruAccessibilityService.suppressLauncherNavigationUntilMs} " +
                "now=${System.currentTimeMillis()}",
        )
        // Scatola nera: init difensivo (idempotente — di norma gia' montata da
        // KoruApplication.onCreate) + marker di creazione Activity con la route
        // iniziale, cosi' nel file si vede se il cold start e' partito su
        // /launcher (preferiti) o su /home.
        BlackBox.init(applicationContext)
        BlackBox.log(
            "ACT",
            "onCreate action=${intent?.action} isHome=${intent?.let { isHomeIntent(it) }} " +
                "isDefault=${isDefaultLauncher()} initialRoute=${getInitialRoute()}",
        )
        // Defense-in-depth: assicura che la foreground service di
        // backup sia viva se l'utente ha già configurato qualcosa che
        // richiede blocking. Cosi' anche se l'AccessibilityService
        // viene killata da OEM aggressivi (ColorOS/MIUI/Samsung) il
        // polling loop continua a far rispettare profili e daily limits.
        // Idempotente: niente succede se è già running.
        ensureBackupBlockingServiceStarted()
        // SEC-12: cold start con l'intent di KoruDeviceAdminReceiver
        // (EXTRA_REQUIRE_BACKDOOR_CODE). configureFlutterEngine NON è ancora
        // girato, quindi NavigationMethodChannel.channel è null → la richiesta
        // viene marcata come pendente e il listener Dart la fa PULL appena
        // registra il proprio handler. Non navighiamo qui (Flutter non è pronto).
        maybeRequireBackdoorCode(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BlockingMethodChannel.register(flutterEngine, this)
        ProfileMethodChannel.register(flutterEngine, this)
        StrictModeMethodChannel.register(flutterEngine, this)
        ServiceEventChannel.register(flutterEngine)
        PermissionMethodChannel.register(flutterEngine, this)
        NavigationMethodChannel.register(flutterEngine)
        BatteryEventChannel.register(flutterEngine, applicationContext)
        BlackBoxMethodChannel.register(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Rilascia sink/handler dei channel longevi prima che l'engine
        // venga distrutto, così non restano reference a sink morti.
        ServiceEventChannel.detach()
        NavigationMethodChannel.detach()
        super.cleanUpFlutterEngine(flutterEngine)
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
        // Posticipiamo di 1.5s per dare a Drift tempo di completare la
        // propria inizializzazione (LazyDatabase + migration onCreate) —
        // aprire il DB via android.database.sqlite mentre Drift sta ancora
        // creando le tabelle puo' produrre file ausiliari incoerenti.
        Handler(Looper.getMainLooper()).postDelayed({
            Thread {
                val hasProfiles = try {
                    NativeDatabase.getEnabledProfiles(applicationContext).isNotEmpty()
                } catch (_: Exception) { false }
                if (hasProfiles) {
                    Handler(Looper.getMainLooper()).post { startBackupBlockingServiceNow() }
                }
            }.start()
        }, 1500L)
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
        BlackBox.log("ACT", "onStart — Activity visibile (foreground)")
        if (packageEventsReceiver == null) {
            val receiver = PackageEventsReceiver()
            // Android 14 (API 34) richiede esplicitamente il flag
            // RECEIVER_NOT_EXPORTED / RECEIVER_EXPORTED per i context-
            // registered receiver, pena SecurityException. I broadcast
            // PACKAGE_ADDED/REMOVED/REPLACED arrivano dal sistema e non
            // devono essere esposti ad altre app → NOT_EXPORTED.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(
                    receiver,
                    PackageEventsReceiver.newFilter(),
                    Context.RECEIVER_NOT_EXPORTED,
                )
            } else {
                registerReceiver(receiver, PackageEventsReceiver.newFilter())
            }
            packageEventsReceiver = receiver
        }
    }

    override fun onStop() {
        super.onStop()
        // Segnale chiave: da qui in poi il processo e' in background e diventa
        // candidabile al low-memory kill. Un `PROC Application.onCreate` che
        // compare DOPO questo (senza un onStart nel mezzo) = killato in
        // background e ricreato a freddo.
        BlackBox.log("ACT", "onStop — Activity in background (candidabile al kill)")
        packageEventsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // già deregistrato — safe da ignorare
            }
        }
        packageEventsReceiver = null
    }

    override fun onResume() {
        super.onResume()
        BlackBox.log("ACT", "onResume — Activity in primo piano e interattiva")
    }

    override fun onDestroy() {
        BlackBox.log("ACT", "onDestroy — Activity distrutta")
        super.onDestroy()
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
        // SEC-12: se l'intent chiede il backdoor code (l'utente sta tentando di
        // disabilitare il device admin con strict mode attivo) apriamo il prompt
        // e fermiamoci qui — ha priorità sulla navigazione launcher/home.
        if (maybeRequireBackdoorCode(intent)) return
        val now = System.currentTimeMillis()
        val suppressUntil = KoruAccessibilityService.suppressLauncherNavigationUntilMs
        val isHome = isHomeIntent(intent)
        val isDefault = isDefaultLauncher()
        Log.d(
            "MainActivity",
            "onNewIntent: action=${intent.action} isHome=$isHome isDefault=$isDefault " +
                "now=$now suppressUntil=$suppressUntil suppressed=${now < suppressUntil}",
        )
        // Warm path: l'Activity esiste gia' (singleTask), niente cold start. Se i
        // preferiti spariscono SENZA un PROC onCreate vicino, NON e' un kill —
        // e' un re-render a vuoto warm (pista diversa).
        BlackBox.log(
            "ACT",
            "onNewIntent (WARM) isHome=$isHome isDefault=$isDefault suppressed=${now < suppressUntil}",
        )
        if (now < suppressUntil) {
            // Reset del flag: la soppressione vale solo per il singolo
            // intent appena ricevuto, non per quelli successivi.
            KoruAccessibilityService.suppressLauncherNavigationUntilMs = 0L
            Log.i("MainActivity", "onNewIntent: navigation suppressed (block-triggered HOME)")
            return
        }
        if (isHome && isDefault) {
            NavigationMethodChannel.goToLauncher()
        } else {
            NavigationMethodChannel.goToHomeIfOnLauncher()
        }
    }

    /**
     * SEC-12: se [intent] porta l'extra [KoruDeviceAdminReceiver.EXTRA_REQUIRE_BACKDOOR_CODE]
     * (settato da [KoruDeviceAdminReceiver.onDisableRequested] quando l'utente
     * tenta di disabilitare il device admin con strict mode attivo), inoltra a
     * Flutter la richiesta di aprire il prompt del backdoor code via
     * [NavigationMethodChannel.goToBackdoorPrompt] e ritorna true.
     *
     * Consuma l'extra (lo rimuove dall'intent) per non riaprire il prompt a ogni
     * successivo onNewIntent/onResume che riusa lo stesso intent.
     */
    private fun maybeRequireBackdoorCode(intent: Intent?): Boolean {
        if (intent == null) return false
        if (!intent.getBooleanExtra(KoruDeviceAdminReceiver.EXTRA_REQUIRE_BACKDOOR_CODE, false)) {
            return false
        }
        Log.i("MainActivity", "SEC-12: backdoor code prompt requested (device-admin disable)")
        intent.removeExtra(KoruDeviceAdminReceiver.EXTRA_REQUIRE_BACKDOOR_CODE)
        setIntent(intent)
        NavigationMethodChannel.goToBackdoorPrompt()
        return true
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
