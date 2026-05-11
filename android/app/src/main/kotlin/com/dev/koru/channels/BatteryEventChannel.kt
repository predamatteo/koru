package com.dev.koru.channels

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/// Event channel `com.koru/battery` — emette level (0-100) + charging flag
/// ad ogni broadcast `ACTION_BATTERY_CHANGED` di sistema (è "sticky": la
/// `registerReceiver` ritorna immediatamente l'ultimo stato cached,
/// quindi non serve un emit iniziale separato).
///
/// Sostituisce il polling Dart (30s level + 10s charging) che drenava
/// batteria anche in background. Il broadcast è "free" — Android lo
/// emette quando lo stato cambia davvero, non a frequenza fissa.
///
/// IMPORTANTE: la `registerReceiver` qui è effettuata sul `applicationContext`
/// così sopravvive a rotazioni di Activity. La `unregisterReceiver` in
/// `onCancel` evita leak quando il subscriber Dart si stacca.
///
/// REGISTRAZIONE: questo file NON si auto-registra. Va aggiunto a
/// `MainActivity.configureFlutterEngine` con qualcosa come:
///
///     BatteryEventChannel.register(flutterEngine, applicationContext)
class BatteryEventChannel(private val context: Context) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                i?.let { emit(it) }
            }
        }
        receiver = r
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        // registerReceiver per ACTION_BATTERY_CHANGED ritorna immediatamente
        // l'ultimo Intent sticky cached: lo emettiamo subito così il primo
        // frame Flutter ha già un valore senza dover aspettare il prossimo
        // cambio di stato.
        val sticky = try {
            context.registerReceiver(r, filter)
        } catch (e: Exception) {
            // Su alcuni OEM/edge cases la registrazione può fallire; in tal
            // caso non emettiamo nulla — il Dart-side mostrerà loading.
            null
        }
        sticky?.let { emit(it) }
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // già deregistrato — safe da ignorare
            }
        }
        receiver = null
        eventSink = null
    }

    private fun emit(intent: Intent) {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
        val pct = if (level >= 0 && scale > 0) (level * 100) / scale else 0
        val status = intent.getIntExtra(
            BatteryManager.EXTRA_STATUS,
            BatteryManager.BATTERY_STATUS_UNKNOWN,
        )
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        try {
            eventSink?.success(mapOf("level" to pct, "charging" to charging))
        } catch (_: IllegalStateException) {
            // sink chiuso dopo un detach del FlutterEngine: niente da fare.
            eventSink = null
        }
    }

    companion object {
        private const val CHANNEL = "com.koru/battery"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setStreamHandler(BatteryEventChannel(context.applicationContext))
        }
    }
}
