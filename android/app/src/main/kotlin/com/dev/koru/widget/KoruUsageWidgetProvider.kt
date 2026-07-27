package com.dev.koru.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.PowerManager
import android.util.Log
import com.dev.koru.diagnostics.BlackBox

/**
 * Widget home "tempo d'uso + limiti".
 *
 * ── PERCHÉ È TUTTO NATIVO ───────────────────────────────────────────────────
 * Uso e limiti sono già disponibili in Kotlin ([com.dev.koru.service.UsageCounter],
 * [com.dev.koru.service.AppUsageLimitsStore]): il widget non tocca né Flutter né
 * il DB Drift. Nessun FlutterEngine da avviare per disegnare una home screen,
 * nessuna dipendenza dal contratto cross-runtime del DB.
 *
 * ── THREADING (il vincolo che detta il design) ──────────────────────────────
 * `onUpdate` / `onAppWidgetOptionsChanged` girano sul MAIN THREAD, che in Koru
 * è condiviso con `KoruAccessibilityService.onAccessibilityEvent` e con il
 * FlutterEngine cachato. Il calcolo dello snapshot è una passata di
 * `queryEvents` su tutta la giornata (centinaia di ms): farla sul main thread
 * significherebbe ritardare l'overlay di blocco esattamente della stessa
 * quantità — cioè bruciare il lavoro fatto per portare evento→overlay da ~315ms
 * a ~180ms. Tutto il lavoro va quindi su [worker], un HandlerThread dedicato,
 * con `goAsync()` a tenere vivo il broadcast finché non abbiamo finito.
 *
 * ── AGGIORNAMENTO: EVENT-DRIVEN, NIENTE POLLING ─────────────────────────────
 * Il widget si ridisegna quando (e solo quando) può essere guardato o quando il
 * dato cambia in modo visibile:
 *  - l'utente torna alla home / sblocca il device (hook in
 *    [com.dev.koru.service.KoruAccessibilityService], throttlato a [MIN_INTERVAL_MS]);
 *  - un limite viene salvato o modificato (`LimitsCallHandler`, forzato);
 *  - un cap giornaliero scatta (ramo USAGE_LIMIT dell'enforcement, forzato).
 * `updatePeriodMillis` nel provider XML resta come rete di sicurezza a 30 min
 * (il minimo che il sistema onora; l'alarm è inexact e non-wakeup, quindi non
 * sveglia il device). Nessun nuovo loop di polling: l'audit batteria ha già
 * identificato le query UsageStats periodiche come causa #1 del consumo a
 * riposo, e questo widget non ne aggiunge.
 *
 * Se nessun widget è piazzato, [requestUpdate] esce prima di qualsiasi lavoro:
 * gli hook sull'hot path costano una lettura di un `@Volatile`.
 */
class KoruUsageWidgetProvider : AppWidgetProvider() {

    /**
     * SICUREZZA — `appWidgetIds` NON è affidabile. `APPWIDGET_UPDATE` non è un
     * protected broadcast (è il meccanismo documentato con cui un'app aggiorna
     * i propri widget) e questo receiver deve essere `exported`, quindi
     * qualunque app installata può inviarcelo con un `EXTRA_APPWIDGET_IDS`
     * arbitrario. Fidandoci del payload:
     *  - un array vuoto spoofato metterebbe `widgetsPresent = false`,
     *    spegnendo tutti gli hook di refresh anche con widget piazzati;
     *  - un array pieno di id inventati farebbe partire uno snapshot completo
     *    (query UsageStats su tutta la giornata) a comando, quante volte
     *    l'attaccante vuole → drenaggio batteria pilotato dall'esterno.
     *
     * Quindi ignoriamo il payload e ripartiamo dagli id REALI chiesti
     * all'AppWidgetManager, intersecandoli con quelli richiesti.
     */
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val owned = ownedWidgetIds(context, appWidgetManager)
        setWidgetsPresent(context, owned.isNotEmpty())
        val targets = appWidgetIds.filter { it in owned }.toIntArray()
        // goAsync() è valido perché onUpdate viene invocata DENTRO onReceive:
        // il PendingResult del broadcast è ancora sullo stack.
        renderAsync(context, targets, goAsyncOrNull())
    }

    /**
     * Resize del widget. Il sistema NON richiama `onUpdate` dopo un resize:
     * se non ridisegniamo qui, un widget allargato resta con le righe di prima.
     *
     * Diversi launcher invocano questo callback più volte con gli stessi
     * valori (e anche al bind iniziale): confrontiamo l'altezza con l'ultima
     * vista e usciamo se identica, altrimenti pagheremmo N query UsageStats
     * per nulla.
     *
     * Il confronto usa MIN **e** MAX height insieme, non solo MAX: il
     * launcher pubblica le due chiavi come bounds sui due orientamenti e il
     * renderer legge MAX in portrait, MIN in landscape (vedi
     * [UsageWidgetRenderer]). Deduplicando sulla sola MAX, un resize fatto con
     * il launcher in landscape cambierebbe solo MIN e verrebbe scartato qui:
     * il widget resterebbe con le righe della dimensione precedente.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // Stessa difesa di onUpdate: l'id arriva da un broadcast non protetto.
        if (appWidgetId !in ownedWidgetIds(context, appWidgetManager)) return
        val minH = newOptions?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        val maxH = newOptions?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        val signature = "${minH}x$maxH"
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getString(keyHeight(appWidgetId), null) == signature) return
        prefs.edit().putString(keyHeight(appWidgetId), signature).apply()
        renderAsync(context, intArrayOf(appWidgetId), goAsyncOrNull())
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        setWidgetsPresent(context, true)
        BlackBox.log(TAG, "widget aggiunto alla home")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        setWidgetsPresent(context, false)
        // Ultimo widget rimosso: icone e inventario non hanno più consumatori
        // e resterebbero appesi al processo main.
        UsageWidgetDataSource.clearCaches()
        BlackBox.log(TAG, "ultimo widget rimosso")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach { editor.remove(keyHeight(it)) }
        editor.apply()
    }

    companion object {
        private const val TAG = "WIDGET"

        /// Extra portato dall'intent di tap: dice a `MainActivity` su quale
        /// route Flutter aprirsi. Vedi [UsageWidgetRenderer.ROUTE_STATS].
        const val EXTRA_WIDGET_ROUTE = "com.dev.koru.widget.ROUTE"

        private const val PREFS = "koru_widget_prefs"
        private const val KEY_WIDGETS_PRESENT = "widgets_present"

        /// Intervallo minimo fra due ridisegni NON forzati. L'hook "l'utente è
        /// tornato alla home" può scattare più volte al minuto (la tendina
        /// delle notifiche è systemui, che passa dallo stesso ramo): senza
        /// throttle pagheremmo una `queryEvents` su tutta la giornata ogni
        /// volta. 30s è sotto la soglia in cui un minuto di differenza diventa
        /// visibile sul widget.
        private const val MIN_INTERVAL_MS = 30_000L

        /// HandlerThread dedicato: NON riusiamo un dispatcher condiviso per non
        /// contendere con il resto del processo, e soprattutto per serializzare
        /// i ridisegni (due render concorrenti farebbero il doppio del lavoro
        /// per lo stesso risultato). La serializzazione è anche ciò che rende
        /// safe le cache non sincronizzate di [UsageWidgetDataSource]: hanno un
        /// solo lettore/scrittore.
        ///
        /// Il thread nasce pigro alla prima [requestUpdate] e non viene mai
        /// terminato, anche per gli utenti che non piazzeranno mai un widget
        /// (la risoluzione di `widgetsPresent` avviene qui sopra). È una scelta
        /// consapevole: un looper parcheggiato costa un descrittore di thread e
        /// zero CPU, mentre poterlo spegnere e riaccendere introdurrebbe una
        /// race fra `quit()` e il `post` successivo. Stesso compromesso già
        /// adottato da [com.dev.koru.diagnostics.BlackBox].
        private val worker: Handler by lazy {
            val ht = HandlerThread("koru-widget").apply { start() }
            Handler(ht.looper)
        }

        /// `null` = non ancora noto in questo processo; viene risolto dalle
        /// SharedPreferences la prima volta, **sul worker** (vedi
        /// [requestUpdate]). Esiste per evitare un binder call
        /// (`getAppWidgetIds`) su ogni evento dell'hot path: nel caso comune
        /// "nessun widget piazzato" la chiamata si riduce a questa lettura.
        @Volatile
        private var widgetsPresent: Boolean? = null

        @Volatile
        private var lastRenderMs = 0L

        /**
         * Chiede un ridisegno del widget. **Sicura da chiamare dall'hot path**:
         * se nessun widget è piazzato o il throttle non è scaduto esce senza
         * toccare né UsageStats né il PackageManager.
         *
         * @param force salta il throttle. Da usare quando il dato è cambiato in
         *   modo che l'utente deve vedere subito (limite salvato, cap scattato),
         *   non per i semplici "l'utente è tornato alla home".
         */
        @JvmStatic
        fun requestUpdate(context: Context, reason: String, force: Boolean = false) {
            // Fast-path: nessun widget piazzato (stato GIÀ noto in questo
            // processo) ⇒ una sola lettura di @Volatile e via. È il caso
            // normale per la maggior parte degli utenti e deve costare zero
            // sull'hot path dell'AccessibilityService.
            if (widgetsPresent == false) return
            val now = System.currentTimeMillis()
            if (!force && now - lastRenderMs < MIN_INTERVAL_MS) return
            lastRenderMs = now
            val appContext = context.applicationContext
            worker.post {
                // Schermo spento ⇒ nessuno può guardare il widget: ridisegnarlo
                // sarebbe una `queryEvents` su tutta la giornata regalata al
                // nulla. Serve davvero: il ramo SKIP_PACKAGES che ci chiama
                // scatta anche sulle finestre di systemui/keyguard, quindi
                // senza questa guardia bloccare il telefono e lasciarlo sul
                // comodino produrrebbe render ricorrenti a schermo spento —
                // esattamente il pattern che l'audit batteria ha eliminato da
                // LockRunnable. Nulla va perso: al primo sblocco
                // `handleUserPresent` richiede un refresh.
                if (!isScreenOn(appContext)) return@post
                // La risoluzione "ci sono widget?" avviene QUI, non sul
                // chiamante: la prima `getSharedPreferences` di un file apre e
                // parsa l'XML in modo SINCRONO, e il chiamante è il main
                // thread dentro `onAccessibilityEvent`. Farlo lì significherebbe
                // infilare un'I/O di disco nel percorso che decide quanto
                // velocemente compare l'overlay di blocco.
                if (!hasWidgets(appContext)) return@post
                renderAllBlocking(appContext, reason)
            }
        }

        /// Ridisegna [appWidgetIds] sul worker, chiudendo il [pendingResult]
        /// del broadcast in ogni caso (anche su eccezione): un PendingResult
        /// non chiuso lascia il broadcast appeso finché non scade il timeout.
        private fun renderAsync(
            context: Context,
            appWidgetIds: IntArray,
            pendingResult: PendingResult?,
        ) {
            if (appWidgetIds.isEmpty()) {
                pendingResult?.finish()
                return
            }
            val appContext = context.applicationContext
            worker.post {
                // `Throwable`, non `Exception`: un guasto del widget non deve
                // MAI abbattere il processo che ospita il motore di blocco.
                // Un'eccezione non catturata su un HandlerThread arriva
                // all'uncaught handler e uccide l'intero processo — e i casi
                // realistici qui sono Error, non Exception (NoSuchMethodError
                // da un metodo mancante su una API vecchia, OutOfMemoryError
                // rasterizzando un'icona). Stessa postura di BlackBox: il
                // sottosistema diagnostico/accessorio fallisce da solo.
                try {
                    lastRenderMs = System.currentTimeMillis()
                    renderIds(appContext, appWidgetIds)
                } catch (t: Throwable) {
                    Log.e(TAG, "render widget fallito", t)
                } finally {
                    try {
                        pendingResult?.finish()
                    } catch (_: Exception) {
                        // Broadcast già scaduto: niente da chiudere.
                    }
                }
            }
        }

        /// Gli id dei widget REALMENTE piazzati da questa app. Unica fonte di
        /// verità: gli id che arrivano dai broadcast sono attacker-controlled
        /// (vedi la nota di sicurezza su [onUpdate]).
        private fun ownedWidgetIds(context: Context, manager: AppWidgetManager?): Set<Int> = try {
            (manager ?: AppWidgetManager.getInstance(context))
                ?.getAppWidgetIds(ComponentName(context, KoruUsageWidgetProvider::class.java))
                ?.toSet()
                ?: emptySet()
        } catch (e: Exception) {
            Log.w(TAG, "getAppWidgetIds fallita", e)
            emptySet()
        }

        private fun renderAllBlocking(context: Context, reason: String) {
            try {
                val manager = AppWidgetManager.getInstance(context) ?: return
                val ids = ownedWidgetIds(context, manager).toIntArray()
                if (ids.isEmpty()) {
                    setWidgetsPresent(context, false)
                    return
                }
                val t0 = System.currentTimeMillis()
                renderIds(context, ids)
                BlackBox.log(
                    TAG,
                    "refresh ($reason) ${ids.size} widget in ${System.currentTimeMillis() - t0}ms",
                )
            } catch (t: Throwable) {
                // Vedi la nota in renderAsync: mai far cadere il processo del
                // motore di blocco per colpa del widget.
                Log.e(TAG, "refresh widget fallito ($reason)", t)
            }
        }

        /// Uno snapshot solo, riusato per tutti i widget: la query UsageStats è
        /// la parte costosa e non dipende dall'id: cambia solo quante righe
        /// entrano nel singolo widget.
        private fun renderIds(context: Context, appWidgetIds: IntArray) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val snapshot = UsageWidgetDataSource.snapshot(context)
            for (id in appWidgetIds) {
                try {
                    manager.updateAppWidget(
                        id,
                        UsageWidgetRenderer.render(context, manager, id, snapshot),
                    )
                } catch (e: Exception) {
                    // Un widget rimosso mentre eravamo sul worker, o una
                    // RemoteViews rifiutata dall'host: non deve impedire il
                    // rendering degli altri.
                    Log.w(TAG, "updateAppWidget($id) fallita", e)
                }
            }
        }

        /// `PowerManager` risolto una volta sola: `getSystemService` non è
        /// gratis (lookup in ServiceManager) e questa guardia sta sul percorso
        /// di ogni refresh — stessa ottimizzazione "O12" già applicata al loop
        /// di [com.dev.koru.service.LockRunnable].
        @Volatile
        private var powerManager: PowerManager? = null

        /// Fail-OPEN: se PowerManager non è disponibile assumiamo schermo
        /// acceso. Un render di troppo è preferibile a un widget che smette di
        /// aggiornarsi per sempre su un device che risponde in modo anomalo.
        private fun isScreenOn(context: Context): Boolean = try {
            val pm = powerManager
                ?: (context.getSystemService(Context.POWER_SERVICE) as? PowerManager)
                    ?.also { powerManager = it }
            pm?.isInteractive ?: true
        } catch (e: Exception) {
            Log.w(TAG, "stato schermo non leggibile: assumo acceso", e)
            true
        }

        private fun hasWidgets(context: Context): Boolean {
            widgetsPresent?.let { return it }
            val stored = try {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getBoolean(KEY_WIDGETS_PRESENT, false)
            } catch (_: Exception) {
                false
            }
            widgetsPresent = stored
            return stored
        }

        private fun setWidgetsPresent(context: Context, present: Boolean) {
            widgetsPresent = present
            try {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(KEY_WIDGETS_PRESENT, present)
                    .apply()
            } catch (e: Exception) {
                Log.w(TAG, "persistenza flag widget fallita", e)
            }
        }

        private fun keyHeight(appWidgetId: Int) = "height_$appWidgetId"
    }

    /// `goAsync()` lancia se il PendingResult non è più disponibile (callback
    /// invocata fuori da un broadcast, es. da un test o da un host anomalo).
    /// In quel caso il lavoro parte comunque, solo senza tenere vivo il
    /// broadcast — che non esiste.
    private fun goAsyncOrNull(): PendingResult? = try {
        goAsync()
    } catch (_: Exception) {
        null
    }
}
