package com.dev.koru.channels

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Canale one-way native → Dart per richiedere cambi di route a GoRouter
/// senza passare da un rebuild dell'Activity. Usato quando MainActivity
/// riceve un nuovo HOME intent (launchMode=singleTop) mentre l'utente è
/// in un'altra schermata: senza segnale, Flutter resta sulla route
/// precedente finché l'utente non interagisce.
object NavigationMethodChannel {
    private const val CHANNEL = "com.koru/navigation"
    private var channel: MethodChannel? = null

    fun register(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    fun goToLauncher() {
        channel?.invokeMethod("goToLauncher", null)
    }
}
