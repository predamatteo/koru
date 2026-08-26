package com.dev.koru.inventory

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log

/**
 * Sorgente **unica** dei due set di package che [PackageVisibility] consuma:
 * gli apribili (MAIN + CATEGORY_LAUNCHER) e i launcher (CATEGORY_HOME).
 *
 * ## Perché una cache
 *
 * `queryIntentActivities` ritorna un `ResolveInfo` per ciascuna delle ~150
 * activity launchable di un device e costringe il framework ad aprire le
 * risorse dell'APK bersaglio: è il lavoro che `AppInventoryCallHandler`
 * documenta come dominante nel cold start. I chiamanti però la invocano
 * spesso — il widget si ridisegna anche ogni 30s, `getUsageStats` parte a ogni
 * cambio periodo e a ogni pull-to-refresh — mentre il set di app installate
 * cambia forse una volta a settimana.
 *
 * Il TTL (invece di un invalidamento sui package event) è deliberato:
 * `PackageEventsReceiver` vive solo mentre l'Activity è visibile, quindi non è
 * una sorgente affidabile per il widget né per il processo di servizio.
 * Prezzo: un'app appena installata può comparire con qualche minuto di
 * ritardo. Il codice è quello che stava in `UsageWidgetDataSource`, clausola
 * anti-orologio-all'indietro inclusa.
 *
 * Thread-safety: `@Synchronized` sui metodi pubblici. I chiamanti sono il
 * worker del widget, il thread del MethodChannel e l'AccessibilityService.
 */
object PackageInventory {

    private const val TAG = "PackageInventory"
    private const val TTL_MS = 5 * 60 * 1000L

    private var loadedAtMs = 0L
    private var launchable: Set<String> = emptySet()
    private var home: Set<String> = emptySet()

    /// Package con un'activity MAIN + CATEGORY_LAUNCHER (hanno un'icona nel
    /// drawer). Set vuoto = query fallita ⇒ i consumatori spengono il filtro
    /// (vedi la nota fail-open di [PackageVisibility]).
    @Synchronized
    fun launchablePackages(context: Context): Set<String> {
        refreshIfStale(context)
        return launchable
    }

    /// Package che dichiarano un'activity CATEGORY_HOME: sono gli altri
    /// launcher installati (Nova, Pixel Launcher, Lawnchair…). Include Koru
    /// stessa, che è un launcher a tutti gli effetti — chi vuole tenerla passa
    /// `keepSelf = true` a [PackageVisibility.isUserFacing].
    @Synchronized
    fun homePackages(context: Context): Set<String> {
        refreshIfStale(context)
        return home
    }

    /// Svuota la cache. Chiamata quando l'ultimo widget viene rimosso e dai
    /// test, che altrimenti si porterebbero dietro lo stato fra un caso e
    /// l'altro.
    @Synchronized
    fun clearCaches() {
        launchable = emptySet()
        home = emptySet()
        loadedAtMs = 0L
    }

    private fun refreshIfStale(context: Context) {
        val now = System.currentTimeMillis()
        // `now < loadedAtMs` copre l'orologio spostato all'indietro: senza, la
        // cache resterebbe valida fino al recupero del delta.
        if (loadedAtMs != 0L && now - loadedAtMs in 0 until TTL_MS) return
        val pm = context.packageManager
        launchable = query(pm, Intent.CATEGORY_LAUNCHER)
        home = query(pm, Intent.CATEGORY_HOME)
        loadedAtMs = now
    }

    private fun query(pm: PackageManager, category: String): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(category)
        return try {
            pm.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        } catch (e: Exception) {
            Log.w(TAG, "queryIntentActivities($category) fallita: filtro disattivato", e)
            emptySet()
        }
    }
}
