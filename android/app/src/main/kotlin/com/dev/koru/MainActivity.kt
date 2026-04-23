package com.dev.koru

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dev.koru.channels.BlockingMethodChannel
import com.dev.koru.channels.NavigationMethodChannel
import com.dev.koru.channels.PackageEventsReceiver
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.StrictModeMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.channels.PermissionMethodChannel

class MainActivity : FlutterActivity() {
    private var packageEventsReceiver: PackageEventsReceiver? = null

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
     * Registriamo il receiver di PACKAGE_ADDED/REMOVED/REPLACED solo mentre
     * l'activity è visibile (onStart/onStop): l'unico consumer è la UI della
     * lista app. Android 8+ non consente la dichiarazione nel Manifest per
     * questi broadcast, quindi la registrazione dev'essere dinamica.
     */
    override fun onStart() {
        super.onStart()
        if (packageEventsReceiver == null) {
            val receiver = PackageEventsReceiver()
            registerReceiver(receiver, PackageEventsReceiver.newFilter())
            packageEventsReceiver = receiver
        }
    }

    override fun onStop() {
        super.onStop()
        packageEventsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // già deregistrato — safe da ignorare
            }
        }
        packageEventsReceiver = null
    }

    /**
     * Route iniziale Flutter: `/launcher` SOLO quando l'intent di lancio è
     * HOME E Koru è effettivamente il launcher di default del sistema.
     * Altrimenti (aperta da drawer, task switcher, o HOME intent residuo
     * dopo che l'utente ha cambiato default launcher) partiamo da `/` →
     * GoRouter redirige a `/home`.
     */
    override fun getInitialRoute(): String? {
        val current = intent ?: return super.getInitialRoute()
        return if (isHomeIntent(current) && isDefaultLauncher()) {
            "/launcher"
        } else {
            super.getInitialRoute()
        }
    }

    /**
     * MainActivity è `singleTask`: un nuovo intent non ricrea l'activity,
     * fa partire onNewIntent. Due casi:
     * - HOME intent + Koru default launcher → naviga Flutter a `/launcher`.
     * - Qualsiasi altro intent (drawer / task switcher / HOME senza essere
     *   default) → se Flutter è parcheggiato su `/launcher` (residuo di
     *   una sessione in cui Koru era default), uscine verso `/home`.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isHomeIntent(intent) && isDefaultLauncher()) {
            NavigationMethodChannel.goToLauncher()
        } else {
            NavigationMethodChannel.goToHomeIfOnLauncher()
        }
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
