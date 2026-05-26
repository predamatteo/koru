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

    /// SEC-12: richiesta di aprire il prompt del backdoor code arrivata mentre
    /// il channel/handler Dart non era ancora pronto (cold start: MainActivity
    /// lanciata da KoruDeviceAdminReceiver.onDisableRequested prima che il
    /// FlutterEngine e il listener Dart fossero attivi). La conserviamo: il
    /// listener Dart, appena registra il proprio handler, fa PULL via
    /// `consumePendingBackdoorPrompt` e la consuma. Così l'evento non va perso
    /// e non dipendiamo da un delay fragile. `@Volatile`: cross-thread.
    @Volatile
    private var pendingBackdoorPrompt: Boolean = false

    fun register(flutterEngine: FlutterEngine) {
        val mc = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        // Handler per il PULL dal Dart (cold-start): il listener chiede se c'è
        // un prompt backdoor in sospeso e lo consuma atomicamente.
        mc.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingBackdoorPrompt" -> {
                    val pending = pendingBackdoorPrompt
                    pendingBackdoorPrompt = false
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
        channel = mc
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

    /// SEC-12: chiede a Flutter di aprire il prompt del backdoor code. Invocata
    /// da [com.dev.koru.MainActivity] quando l'intent porta l'extra
    /// [com.dev.koru.strictmode.KoruDeviceAdminReceiver.EXTRA_REQUIRE_BACKDOOR_CODE]
    /// (l'utente sta tentando di disabilitare il device admin con strict mode
    /// attivo). Warm path (app già viva, channel pronto): push diretto del
    /// metodo `requireBackdoorCode`. Cold path (channel non ancora registrato):
    /// segna la richiesta come pendente; il listener Dart la consuma via
    /// `consumePendingBackdoorPrompt` appena registra l'handler, così il
    /// deterrent non va perso.
    fun goToBackdoorPrompt() {
        if (channel == null) {
            pendingBackdoorPrompt = true
            return
        }
        invokeSafely("requireBackdoorCode")
    }

    /// Test-only: stato del flag di prompt pendente (SEC-12). `internal` per
    /// evitare reflection nei test, senza esporlo all'API pubblica del channel.
    internal fun isBackdoorPromptPendingForTest(): Boolean = pendingBackdoorPrompt

    /// Test-only: azzera lo stato del channel (il singleton `object` persiste tra
    /// i test nello stesso JVM). Riporta channel e pending allo stato vergine.
    internal fun resetForTest() {
        channel = null
        pendingBackdoorPrompt = false
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
