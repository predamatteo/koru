package com.dev.koru.channels

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

object ServiceEventChannel {
    private const val CHANNEL = "com.koru/service_events"
    private val mainHandler = Handler(Looper.getMainLooper())
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

    /// Safe da chiamare da qualsiasi thread — Flutter richiede EventSink sul main.
    fun sendEvent(jsonString: String) {
        mainHandler.post { eventSink?.success(jsonString) }
    }
}
