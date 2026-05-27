package com.dev.koru.channels

import android.app.Activity
import com.dev.koru.channels.blocking.AppActionsCallHandler
import com.dev.koru.channels.blocking.AppInventoryCallHandler
import com.dev.koru.channels.blocking.BlockingCallHandler
import com.dev.koru.channels.blocking.DeviceInfoCallHandler
import com.dev.koru.channels.blocking.LimitsCallHandler
import com.dev.koru.channels.blocking.NotificationFilterCallHandler
import com.dev.koru.channels.blocking.QuickBlockCallHandler
import com.dev.koru.channels.blocking.ServiceLifecycleCallHandler
import com.dev.koru.channels.blocking.UsageStatsCallHandler
import com.dev.koru.channels.blocking.WifiCallHandler
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Router sottile del MethodChannel `com.koru/blocking`.
 *
 * ARCH-09: prima questo era un god-facade da ~558 righe con un `when` di ~29
 * cases che mescolava 7+ concern (service lifecycle, inventory app, usage-stats,
 * quick-block/pomodoro, azioni app, device-info, limiti giornalieri + bypass,
 * filtro notifiche, wifi). Ora ogni concern vive in un [BlockingCallHandler]
 * dedicato sotto `channels/blocking/`; qui resta SOLO il routing.
 *
 * WIRE-CONTRACT INVARIATO: il nome del canale ([CHANNEL]) e la registrazione in
 * `MainActivity.configureFlutterEngine` restano identici. Nessun metodo è stato
 * rinominato, spostato su un altro canale, o cambiato negli argomenti / shape
 * del risultato. La decomposizione è puramente interna → niente rischio di
 * `MissingPluginException` a runtime. L'UNICA differenza di comportamento
 * voluta è CR-09 (vedi [LimitsCallHandler] / [NotificationFilterCallHandler]):
 * `setAppDailyLimits` e `setSilencedPackages` ora ritornano il vero esito del
 * salvataggio (Boolean) invece di `true` incondizionato.
 */
object BlockingMethodChannel {
    private const val CHANNEL = "com.koru/blocking"

    /// Tutti gli handler per-concern. L'ordine è irrilevante per il dispatch
    /// (la tabella è keyed per method name e [routingTable] verifica che non
    /// ci siano collisioni), ma li teniamo raggruppati per leggibilità.
    private val handlers: List<BlockingCallHandler> = listOf(
        ServiceLifecycleCallHandler,
        AppInventoryCallHandler,
        UsageStatsCallHandler,
        QuickBlockCallHandler,
        AppActionsCallHandler,
        DeviceInfoCallHandler,
        LimitsCallHandler,
        NotificationFilterCallHandler,
        WifiCallHandler,
    )

    /**
     * Mappa `method name → handler`. Costruita una volta. Se due handler
     * dichiarassero lo stesso metodo è un errore di programmazione (un metodo
     * appartiene a esattamente un concern): falliamo fast con
     * [IllegalStateException] invece di far vincere silenziosamente uno dei due.
     * Esposta `internal` così un unit test può asseverare l'intera tabella di
     * dispatch (nessun metodo droppato / duplicato durante la decomposizione).
     */
    internal val routingTable: Map<String, BlockingCallHandler> by lazy {
        val table = HashMap<String, BlockingCallHandler>()
        for (handler in handlers) {
            for (method in handler.methods) {
                val previous = table.put(method, handler)
                check(previous == null) {
                    "Metodo '$method' dichiarato da piu' handler: " +
                        "${previous!!::class.simpleName} e ${handler::class.simpleName}"
                }
            }
        }
        table
    }

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        val table = routingTable
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val handler = table[call.method]
                if (handler != null) {
                    handler.handle(call, result, activity)
                } else {
                    result.notImplemented()
                }
            }
    }
}
