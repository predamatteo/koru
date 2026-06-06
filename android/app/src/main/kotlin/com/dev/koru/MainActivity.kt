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
import io.flutter.embedding.engine.FlutterEngineCache
import com.dev.koru.channels.NavigationMethodChannel
import com.dev.koru.channels.PackageEventsReceiver
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.db.NativeDatabase
import com.dev.koru.diagnostics.BlackBox
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.LockForegroundService
import com.dev.koru.strictmode.KoruDeviceAdminReceiver

class MainActivity : FlutterActivity() {
    private var packageEventsReceiver: PackageEventsReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Engine cacheato: scaldiamo (o riusiamo) l'unico FlutterEngine PRIMA di
        // super.onCreate, così il delegate di FlutterActivity — che legge
        // getCachedEngineId() durante super.onCreate — trova l'engine già in
        // cache e vi si aggancia SENZA rilanciare main() (niente cold start su
        // una semplice ricreazione dell'Activity).
        val initialRoute = computeInitialRoute()
        val freshlyWarmed = KoruEngineManager.ensureWarm(this, initialRoute)
        super.onCreate(savedInstanceState)
        Log.d(
            "MainActivity",
            "onCreate: action=${intent?.action} isHome=${intent?.let { isHomeIntent(it) }} " +
                "freshlyWarmed=$freshlyWarmed " +
                "suppressUntil=${KoruAccessibilityService.suppressLauncherNavigationUntilMs} " +
                "now=${System.currentTimeMillis()}",
        )
        // Scatola nera: init difensivo (idempotente — di norma gia' montata da
        // KoruApplication.onCreate) + marker di creazione Activity. `cachedEngine
        // =true` ⇒ engine RIUSATO (ricreazione Activity a processo vivo, niente
        // main()); `savedState` distingue una ricreazione con stato salvato da un
        // cold start vero del processo.
        BlackBox.init(applicationContext)
        BlackBox.log(
            "ACT",
            "onCreate action=${intent?.action} isHome=${intent?.let { isHomeIntent(it) }} " +
                "isDefault=${isDefaultLauncher()} initialRoute=$initialRoute " +
                "cachedEngine=${!freshlyWarmed} savedState=${savedInstanceState != null}",
        )
        // Defense-in-depth: assicura che la foreground service di
        // backup sia viva se l'utente ha già configurato qualcosa che
        // richiede blocking. Cosi' anche se l'AccessibilityService
        // viene killata da OEM aggressivi (ColorOS/MIUI/Samsung) il
        // polling loop continua a far rispettare profili e daily limits.
        // Idempotente: niente succede se è già running.
        ensureBackupBlockingServiceStarted()
        // SEC-12: cold start con l'intent di KoruDeviceAdminReceiver
        // (EXTRA_REQUIRE_BACKDOOR_CODE). Con engine cached il
        // NavigationMethodChannel è registrato al warm; se per qualche motivo il
        // suo channel fosse ancora null la richiesta resta pendente e il listener
        // Dart la fa PULL appena registra l'handler (meccanismo invariato).
        maybeRequireBackdoorCode(intent)
        // Re-attach a un engine GIÀ caldo: la route iniziale non si applica più
        // (main() è già girato; Dart è sulla pagina dell'ultima sessione).
        // Navighiamo in base all'intent di lancio rispettando la finestra di
        // soppressione del blocking engine (stessa policy di onNewIntent). Sul
        // warm fresco invece ci pensa la initialRoute passata all'engine.
        if (!freshlyWarmed) {
            routeForLaunchIntent()
        }
    }

    /// FlutterActivity userà l'engine cacheato da [KoruEngineManager] se
    /// presente. Se il warm è fallito (cache vuota) ritorniamo null →
    /// FlutterActivity crea un engine proprio (comportamento legacy, distrutto
    /// con l'host). Letto dal delegate durante super.onCreate, dopo ensureWarm.
    override fun getCachedEngineId(): String? =
        if (FlutterEngineCache.getInstance().contains(KoruEngineManager.ENGINE_ID)) {
            KoruEngineManager.ENGINE_ID
        } else {
            null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val t0 = System.currentTimeMillis()
        super.configureFlutterEngine(flutterEngine)
        val isCached =
            FlutterEngineCache.getInstance().get(KoruEngineManager.ENGINE_ID) === flutterEngine
        if (isCached) {
            // Engine pre-warmato: EventChannel + channel context-light sono già
            // stati registrati una volta al warm (ri-registrarli romperebbe la
            // subscription Dart degli EventChannel). Qui ri-agganciamo SOLO i
            // method channel Activity-bound, per puntare all'Activity corrente.
            KoruEngineManager.registerActivityChannels(flutterEngine, this)
        } else {
            // Fallback (warm fallito): engine creato da FlutterActivity → nessun
            // channel è stato registrato al warm, li registriamo tutti qui.
            KoruEngineManager.registerAllChannels(flutterEngine, this)
        }
        BlackBox.log(
            "ACT",
            "configureFlutterEngine (${System.currentTimeMillis() - t0}ms, cached=$isCached)",
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val isCached =
            FlutterEngineCache.getInstance().get(KoruEngineManager.ENGINE_ID) === flutterEngine
        if (!isCached) {
            // Engine per-activity (fallback) che verrà distrutto con l'host:
            // scollega i sink longevi prima del teardown, così un emit
            // successivo non solleva "Reply already submitted".
            ServiceEventChannel.detach()
            NavigationMethodChannel.detach()
        }
        // Engine cached: NON fare detach. Persiste oltre la distruzione
        // dell'Activity e il prossimo attach lo riusa; scollegare il sink di
        // ServiceEventChannel fermerebbe gli eventi del foreground service verso
        // il Dart (che resta vivo) finché un nuovo onListen non lo ripopola.
        BlackBox.log("ACT", "cleanUpFlutterEngine (cached=$isCached)")
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
     *
     * Con engine cacheato questa route viene passata UNA volta al warm
     * (`engine.navigationChannel.setInitialRoute`, vedi [KoruEngineManager]);
     * l'override [getInitialRoute] resta per il path di fallback (engine
     * per-activity) dove FlutterActivity la consulta direttamente.
     */
    private fun computeInitialRoute(): String {
        val current = intent
        return if (current != null && isHomeIntent(current) && isDefaultLauncher()) {
            "/launcher"
        } else {
            "/"
        }
    }

    override fun getInitialRoute(): String? = computeInitialRoute()

    /// Naviga Flutter in base all'intent di lancio quando l'Activity si
    /// ri-aggancia a un engine GIÀ caldo (la initialRoute non si applica più,
    /// `main()` è già girato). Mirror della policy di [onNewIntent]: rispetta la
    /// soppressione del blocking engine, altrimenti HOME+default → `/launcher`,
    /// sennò esce dal launcher se Dart è rimasto lì da una sessione precedente.
    private fun routeForLaunchIntent() {
        val current = intent ?: return
        val now = System.currentTimeMillis()
        val suppressUntil = KoruAccessibilityService.suppressLauncherNavigationUntilMs
        if (now < suppressUntil) {
            KoruAccessibilityService.suppressLauncherNavigationUntilMs = 0L
            return
        }
        if (isHomeIntent(current) && isDefaultLauncher()) {
            NavigationMethodChannel.goToLauncher()
        } else {
            NavigationMethodChannel.goToHomeIfOnLauncher()
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
