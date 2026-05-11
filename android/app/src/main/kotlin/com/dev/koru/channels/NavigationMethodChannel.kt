package com.dev.koru.channels

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Canale one-way native → Dart per richiedere cambi di route a GoRouter
/// senza passare da un rebuild dell'Activity. Usato quando MainActivity
/// riceve un nuovo HOME intent (launchMode=singleTop) mentre l'utente è
/// in un'altra schermata: senza segnale, Flutter resta sulla route
/// precedente finché l'utente non interagisce.
object NavigationMethodChannel {
    private const val CHANNEL = "com.koru/navigation"

    @Volatile
    private var channel: MethodChannel? = null

    fun register(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    /// Chiamabile da `MainActivity.cleanUpFlutterEngine` per scollegare
    /// manualmente la reference quando l'engine viene detached. Senza
    /// questo, un `invokeMethod` post-teardown solleva
    /// `IllegalStateException: BinaryMessenger has been disposed`.
    fun detach() {
        channel = null
    }

    fun goToLauncher() {
        invokeSafely("goToLauncher")
    }

    fun goToHomeIfOnLauncher() {
        invokeSafely("goToHomeIfOnLauncher")
    }

    /// Wrapper difensivo: `invokeMethod` su un channel attached a un
    /// FlutterEngine già disposed solleva `IllegalStateException`. Senza
    /// catch, un onNewIntent ricevuto durante il teardown dell'Activity
    /// (race window stretta ma reale su OEM con management memoria
    /// aggressivo) crasha il processo. Catchiamo e azzeriamo `channel`
    /// così invocazioni successive diventano no-op finché un nuovo
    /// `register` non ripopola.
    private fun invokeSafely(method: String) {
        val c = channel ?: return
        try {
            c.invokeMethod(method, null)
        } catch (e: IllegalStateException) {
            Log.w("NavigationMethodChannel", "channel dead on '$method': ${e.message}")
            channel = null
        } catch (e: Exception) {
            Log.w("NavigationMethodChannel", "invoke '$method' failed: ${e.message}")
        }
    }
}
