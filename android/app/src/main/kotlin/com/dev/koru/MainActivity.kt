package com.dev.koru

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dev.koru.channels.BlockingMethodChannel
import com.dev.koru.channels.NavigationMethodChannel
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.StrictModeMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.channels.PermissionMethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BlockingMethodChannel.register(flutterEngine, this)
        ProfileMethodChannel.register(flutterEngine, this)
        StrictModeMethodChannel.register(flutterEngine, this)
        ServiceEventChannel.register(flutterEngine)
        PermissionMethodChannel.register(flutterEngine, this)
        NavigationMethodChannel.register(flutterEngine)
    }

    /**
     * Se l'intent launching è HOME (utente ha premuto il tasto home con Koru
     * come launcher di default), avvia Flutter direttamente sulla route
     * `/launcher` — la Koru launcher UI full-screen, senza bottom nav.
     * Altrimenti comportamento standard (Flutter parte su `/` e GoRouter
     * redirige a `/home`).
     */
    override fun getInitialRoute(): String? {
        val current = intent ?: return super.getInitialRoute()
        return if (isHomeIntent(current)) "/launcher" else super.getInitialRoute()
    }

    /**
     * MainActivity è `singleTop`: un HOME intent mentre l'app è già in
     * foreground non ricrea l'activity, fa partire onNewIntent. In quel caso
     * Flutter è ancora sulla route precedente (es. /settings). Notifichiamo
     * il lato Dart via [NavigationMethodChannel] così GoRouter salta sulla
     * /launcher immediatamente invece di aspettare un'interazione utente.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isHomeIntent(intent)) {
            NavigationMethodChannel.goToLauncher()
        }
    }

    private fun isHomeIntent(intent: Intent): Boolean =
        intent.action == Intent.ACTION_MAIN &&
            intent.categories?.contains(Intent.CATEGORY_HOME) == true
}
