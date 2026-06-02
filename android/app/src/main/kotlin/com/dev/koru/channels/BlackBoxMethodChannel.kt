package com.dev.koru.channels

import com.dev.koru.diagnostics.BlackBox
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte Dart -> [BlackBox] nativa. Permette al lato Flutter di scrivere sulla
 * STESSA scatola nera dei segnali nativi, cosi' la timeline e' unica e
 * correlabile (es. `PROC Application.onCreate` nativo seguito da `FAV first
 * emit` Dart racconta quanto restano vuoti i preferiti dopo un cold start).
 *
 * Handler stateless: nessun riferimento al channel da rilasciare in teardown
 * (a differenza di [NavigationMethodChannel]/[ServiceEventChannel] non spinge
 * mai nulla verso Dart).
 */
object BlackBoxMethodChannel {
    private const val CHANNEL = "com.koru/blackbox"

    fun register(flutterEngine: FlutterEngine) {
        val mc = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        mc.setMethodCallHandler { call, result ->
            when (call.method) {
                "log" -> {
                    val tag = call.argument<String>("tag") ?: "DART"
                    val msg = call.argument<String>("msg") ?: ""
                    BlackBox.log(tag, msg)
                    result.success(null)
                }
                "path" -> result.success(BlackBox.path())
                else -> result.notImplemented()
            }
        }
    }
}
