package com.dev.koru

import android.app.Activity
import android.content.Context
import com.dev.koru.channels.BatteryEventChannel
import com.dev.koru.channels.BlackBoxMethodChannel
import com.dev.koru.channels.BlockingMethodChannel
import com.dev.koru.channels.NavigationMethodChannel
import com.dev.koru.channels.PermissionMethodChannel
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.channels.StrictModeMethodChannel
import com.dev.koru.diagnostics.BlackBox
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Gestore dell'unico FlutterEngine "caldo" di Koru, cacheato in
 * [FlutterEngineCache] sotto [ENGINE_ID].
 *
 * **Perché esiste.** [MainActivity] era un `FlutterActivity` nudo: ogni
 * ricreazione dell'Activity (49 su 56 nei black-box log, SENZA morte del
 * processo) creava un engine nuovo e rilanciava `main()` da zero (scan
 * PackageManager + rebuild del grafo Riverpod + riapertura Drift) → freeze di
 * 6-25s. Riusare un engine cacheato fa girare `main()` UNA volta per processo:
 * tornare alla home diventa warm/istantaneo e lo stato Riverpod (preferiti,
 * inventario) sopravvive alle ricreazioni.
 *
 * **Quando si scalda.** Al PRIMO [MainActivity.onCreate], NON in
 * `KoruApplication.onCreate`: durante le rianimazioni headless del processo (il
 * servizio di accessibilità che lo fa ripartire senza UI) non vogliamo pagare
 * il costo memoria di un engine Flutter caldo — rilevante vista la pressione
 * memoria (`onLowMemory`) sui device OEM aggressivi. L'engine vive quanto il
 * processo e muore con lui (i 7 cold-start veri restano, ma sono rari).
 *
 * **Lifecycle dei channel.**
 *  - [registerEngineChannels] (EventChannel `service_events`/`battery` + i
 *    method channel context-light `navigation`/`blackbox`) si registrano UNA
 *    sola volta, al warm. Con engine persistente la subscription Dart degli
 *    EventChannel resta viva: ri-settare lo StreamHandler a ogni attach NON
 *    rifà `onListen` → il sink resterebbe null e lo stream morirebbe.
 *  - [registerActivityChannels] (`blocking`/`profiles`/`strict_mode`/
 *    `permissions`) si RI-registrano a ogni `configureFlutterEngine` (ogni
 *    attach) così catturano sempre l'Activity CORRENTE; sono request/response,
 *    quindi ri-settare l'handler è sicuro e non perde stato.
 */
object KoruEngineManager {
    const val ENGINE_ID = "koru_main"

    /**
     * Crea e cachea l'engine se non esiste già. Ritorna `true` se è stato
     * scaldato ORA (cold start del processo), `false` se era già in cache
     * (l'Activity si sta solo ri-agganciando → `main()` NON rigira).
     *
     * Non lancia mai: se il warm fallisce lascia la cache vuota e
     * [MainActivity.getCachedEngineId] ritorna null → FlutterActivity ricade
     * sull'engine per-activity legacy (degradazione controllata).
     */
    fun ensureWarm(activity: Activity, initialRoute: String): Boolean {
        val cache = FlutterEngineCache.getInstance()
        if (cache.contains(ENGINE_ID)) return false
        return try {
            val engine = FlutterEngine(activity.applicationContext)
            // Ordine: prima i channel (così le primissime chiamate Dart durante
            // lo startup trovano gli handler), poi la route iniziale, poi
            // l'entrypoint che fa partire `main()`.
            registerEngineChannels(engine, activity.applicationContext)
            registerActivityChannels(engine, activity)
            engine.navigationChannel.setInitialRoute(initialRoute)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
            cache.put(ENGINE_ID, engine)
            BlackBox.log("ACT", "engine WARM creato (id=$ENGINE_ID, route=$initialRoute)")
            true
        } catch (e: Throwable) {
            BlackBox.log("ACT", "engine WARM FALLITO (${e.message}) -> fallback per-activity")
            false
        }
    }

    /// Method channel che catturano l'Activity → ri-registrati a ogni attach.
    fun registerActivityChannels(engine: FlutterEngine, activity: Activity) {
        BlockingMethodChannel.register(engine, activity)
        ProfileMethodChannel.register(engine, activity)
        StrictModeMethodChannel.register(engine, activity)
        PermissionMethodChannel.register(engine, activity)
    }

    /// EventChannel + method channel context-light → registrati UNA volta sola.
    fun registerEngineChannels(engine: FlutterEngine, appContext: Context) {
        ServiceEventChannel.register(engine)
        NavigationMethodChannel.register(engine)
        BatteryEventChannel.register(engine, appContext)
        BlackBoxMethodChannel.register(engine)
    }

    /// Tutto insieme — usato SOLO nel fallback per-activity (warm fallito),
    /// dove nessun channel è stato registrato al warm.
    fun registerAllChannels(engine: FlutterEngine, activity: Activity) {
        registerEngineChannels(engine, activity.applicationContext)
        registerActivityChannels(engine, activity)
    }
}
