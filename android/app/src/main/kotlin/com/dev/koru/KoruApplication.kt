package com.dev.koru

import android.app.Application
import android.content.ComponentCallbacks2
import android.os.Process
import com.dev.koru.diagnostics.BlackBox

/**
 * Application custom: esiste per montare la scatola nera ([BlackBox]) il prima
 * possibile nel ciclo di vita del processo e per intercettare i segnali di
 * pressione memoria che PRECEDONO un kill di sistema.
 *
 * `Application.onCreate` gira ESATTAMENTE una volta per processo: la sua riga di
 * log e' quindi il marker autoritativo di **cold start**. Quando nel file
 * compare un nuovo `PROC Application.onCreate` significa che il processo
 * precedente era stato ucciso (tipicamente in background, scenario classico per
 * un launcher) e il sistema l'ha ricreato — la spiegazione piu' probabile di
 * "preferiti + drawer spariti per un attimo": entrambe le sorgenti ripartono da
 * zero (DB Drift deve ri-emettere, `getInstalledApps` deve riscansionare).
 *
 * In embedding v2 Flutter NON richiede una Application speciale; estendere la
 * piatta [Application] e' il pattern documentato (il manifest la referenzia via
 * `android:name=".KoruApplication"` al posto del placeholder `${applicationName}`).
 */
class KoruApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BlackBox.init(this)
        BlackBox.log(
            "PROC",
            "Application.onCreate pid=${Process.myPid()} — COLD START (processo (ri)creato da zero)",
        )
    }

    /**
     * Segnale di pressione memoria. `TRIM_MEMORY_COMPLETE` in particolare
     * significa "sei in cima alla lista dei prossimi processi da uccidere":
     * vederlo poco prima di un `PROC Application.onCreate` successivo conferma
     * che il cold-start e' stato causato da un low-memory kill in background.
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        BlackBox.log("MEM", "onTrimMemory ${trimName(level)}")
    }

    override fun onLowMemory() {
        super.onLowMemory()
        BlackBox.log("MEM", "onLowMemory — pressione critica, kill del processo possibile")
    }

    private fun trimName(level: Int): String = when (level) {
        ComponentCallbacks2.TRIM_MEMORY_COMPLETE ->
            "COMPLETE (primo a essere killato)"
        ComponentCallbacks2.TRIM_MEMORY_MODERATE ->
            "MODERATE (a meta' della LRU)"
        ComponentCallbacks2.TRIM_MEMORY_BACKGROUND ->
            "BACKGROUND (entrato nella LRU, a rischio)"
        ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN ->
            "UI_HIDDEN (UI non piu' visibile = app in background)"
        ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL ->
            "RUNNING_CRITICAL (foreground ma sistema in affanno)"
        ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ->
            "RUNNING_LOW"
        ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE ->
            "RUNNING_MODERATE"
        else -> "level=$level"
    }
}
