package com.dev.koru.channels

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

object ServiceEventChannel {
    private const val CHANNEL = "com.koru/service_events"
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun register(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /// Chiamabile da `MainActivity.cleanUpFlutterEngine` (o quando l'engine
    /// viene detached) per scollegare manualmente il sink. Senza questa
    /// pulizia, un emit successivo al teardown del FlutterEngine produce
    /// `IllegalStateException: Reply already submitted`. La protezione
    /// runtime in `sendEvent` resta il safety net principale, ma chiamare
    /// `detach()` al lifecycle event esatto è più pulito.
    fun detach() {
        eventSink = null
    }

    /// Safe da chiamare da qualsiasi thread — Flutter richiede EventSink sul main.
    ///
    /// Protetto contro `IllegalStateException` che Flutter solleva se il
    /// sink è già morto (FlutterEngine detached, Activity in fase di
    /// teardown, ecc.). In quel caso azzeriamo `eventSink` così emit
    /// successivi diventano no-op finché un nuovo `onListen` non lo
    /// ripopola.
    fun sendEvent(jsonString: String) {
        mainHandler.post {
            val sink = eventSink ?: return@post
            try {
                sink.success(jsonString)
            } catch (e: IllegalStateException) {
                Log.w("ServiceEventChannel", "EventSink dead, clearing: ${e.message}")
                eventSink = null
            } catch (e: Exception) {
                // Catch-all difensivo: qualsiasi altra eccezione di
                // serializzazione/transport viene loggata ma non propaga,
                // così un singolo evento corrotto non distrugge il
                // foreground service che lo emette.
                Log.w("ServiceEventChannel", "sendEvent failed: ${e.message}")
            }
        }
    }
}
