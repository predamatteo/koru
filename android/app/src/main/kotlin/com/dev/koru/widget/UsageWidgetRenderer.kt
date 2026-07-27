package com.dev.koru.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.widget.RemoteViews
import com.dev.koru.MainActivity
import com.dev.koru.R

/**
 * Costruisce la [RemoteViews] del widget "tempo d'uso + limiti".
 *
 * Le righe sono create a runtime e appese con `addView` invece di essere
 * dichiarate nel layout: così il numero di righe segue l'altezza reale del
 * widget (4x2 → 4x4) senza dover mantenere N layout diversi. Vincoli di quel
 * pattern, tutti rispettati qui:
 *  - ogni riga va configurata COMPLETAMENTE prima di `addView`: dopo, il
 *    parent non può più indirizzare i figli per id (gli id si ripetono su
 *    tutte le righe e la setter colpirebbe la prima corrispondenza);
 *  - `removeAllViews` va chiamato prima del ciclo, altrimenti ad ogni update
 *    le righe si accumulano;
 *  - niente `partiallyUpdateAppWidget`: le sue action non sono persistite e un
 *    `addView` parziale duplicherebbe le righe dopo un restart dell'host.
 *
 * Le icone sono rasterizzate a [ICON_PX] PIXEL (non dp): vedi la nota in
 * [UsageWidgetDataSource.iconBitmap] sul buffer Binder.
 */
internal object UsageWidgetRenderer {

    /// Lato dell'icona in pixel. Fisso, indipendente dalla densità: l'ImageView
    /// è dichiarata 18dp e scala il bitmap, quindi 48px resta nitido anche su
    /// xxhdpi senza gonfiare la transazione verso il launcher.
    private const val ICON_PX = 48

    /// Numero di righe usato quando il launcher non riporta ancora le
    /// dimensioni del widget (bundle vuoto al primo bind, o valori incoerenti
    /// su alcuni OEM). Corrisponde a un 4x2 pieno.
    private const val FALLBACK_ROWS = 3

    /// Margine di sicurezza sottratto all'altezza dichiarata dal launcher:
    /// Android 12+ aggiunge un proprio padding attorno al widget, e senza
    /// questo scarto l'ultima riga risulterebbe tagliata a metà.
    private const val HEIGHT_SAFETY_DP = 8

    /**
     * Renderizza il widget [appWidgetId]. Chiamata dal worker di
     * [KoruUsageWidgetProvider] — mai dal main thread: [UsageWidgetDataSource.snapshot]
     * fa una passata di `queryEvents` su tutta la giornata.
     */
    fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        snapshot: UsageWidgetModel.Snapshot?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_usage)
        views.removeAllViews(R.id.widget_rows)

        if (snapshot == null) {
            // Usage access non concesso: il tap porta direttamente alla
            // schermata di sistema dove si concede, non dentro Koru.
            views.setTextViewText(R.id.widget_header_total, "--")
            showMessage(views, context.getString(R.string.koru_widget_no_permission))
            views.setOnClickPendingIntent(android.R.id.background, usageAccessSettingsIntent(context))
            return views
        }

        views.setTextViewText(
            R.id.widget_header_total,
            UsageWidgetModel.formatDurationMs(snapshot.totalMs),
        )
        views.setOnClickPendingIntent(android.R.id.background, openStatsIntent(context))

        val maxRows = UsageWidgetModel.rowsFittingHeight(
            heightDp = availableHeightDp(manager, appWidgetId),
            candidates = snapshot.rows,
        )
        val rows = snapshot.rows.take(maxRows)

        if (rows.isEmpty()) {
            // Il messaggio deve essere coerente con l'header. Con un totale > 0
            // (tipico se Koru è il launcher di default: il suo tempo entra nel
            // totale ma non nelle righe) dire "nessun utilizzo registrato"
            // contraddirebbe il numero scritto due centimetri più in alto.
            val message = if (snapshot.totalMs > 0) {
                R.string.koru_widget_empty_rows
            } else {
                R.string.koru_widget_empty
            }
            showMessage(views, context.getString(message))
            return views
        }

        views.setViewVisibility(R.id.widget_empty, View.GONE)
        views.setViewVisibility(R.id.widget_rows, View.VISIBLE)
        for (row in rows) {
            views.addView(R.id.widget_rows, buildRow(context, row))
        }
        return views
    }

    /// Riga singola, completamente configurata PRIMA di essere appesa.
    private fun buildRow(context: Context, row: UsageWidgetModel.Row): RemoteViews {
        val limit = row.limitMinutes
        val layout = if (row.hasLimit) {
            R.layout.widget_usage_row_limit
        } else {
            R.layout.widget_usage_row_plain
        }
        val rv = RemoteViews(context.packageName, layout)
        rv.setTextViewText(R.id.row_label, row.label)

        UsageWidgetDataSource.iconBitmap(context, row.packageName, ICON_PX)?.let {
            rv.setImageViewBitmap(R.id.row_icon, it)
        }

        if (!row.hasLimit || limit == null) {
            rv.setTextViewText(R.id.row_value, UsageWidgetModel.formatDurationMs(row.usedMs))
            return rv
        }

        rv.setTextViewText(R.id.row_value, UsageWidgetModel.formatUsedOverCap(row.usedMs, limit))
        rv.setViewVisibility(R.id.row_lock, if (row.strict) View.VISIBLE else View.GONE)

        // Tre barre pre-stilizzate, una sola visibile: il tinting a runtime di
        // una singola ProgressBar richiede `setColorStateList` (API 31) e il
        // minSdk è 28. `setProgressBar` + `setViewVisibility` sono invece
        // primitive RemoteViews disponibili ovunque.
        val percent = UsageWidgetModel.progressPercent(row.usedMs, limit)
        val state = UsageWidgetModel.barStateFor(row.usedMs, limit)
        val activeBar = when (state) {
            UsageWidgetModel.BarState.UNDER -> R.id.row_bar_under
            UsageWidgetModel.BarState.NEAR -> R.id.row_bar_near
            UsageWidgetModel.BarState.OVER -> R.id.row_bar_over
        }
        for (id in intArrayOf(R.id.row_bar_under, R.id.row_bar_near, R.id.row_bar_over)) {
            rv.setViewVisibility(id, if (id == activeBar) View.VISIBLE else View.GONE)
        }
        rv.setProgressBar(activeBar, 100, percent, false)
        return rv
    }

    private fun showMessage(views: RemoteViews, message: String) {
        views.setTextViewText(R.id.widget_empty, message)
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        views.setViewVisibility(R.id.widget_rows, View.GONE)
    }

    /**
     * Altezza utilizzabile in dp.
     *
     * Il launcher pubblica MIN/MAX_HEIGHT come bounds sui DUE orientamenti:
     * `MAX_HEIGHT` è l'altezza in portrait, `MIN_HEIGHT` quella in landscape.
     * Usiamo **sempre MAX_HEIGHT** invece di scegliere in base
     * all'orientamento corrente, perché quell'orientamento non è osservabile
     * da qui: `context.resources.configuration` segue il DISPLAY del processo
     * Koru, non la home screen su cui il widget è disegnato. I due divergono in
     * un caso tutt'altro che teorico — l'utente è dentro un gioco o un video in
     * landscape (il display è landscape) mentre la home resta portrait, ed è
     * proprio lì che scatta il refresh forzato "limit-hit". Leggeremmo il bound
     * landscape per un widget disegnato in portrait, sbagliando il numero di
     * righe. `MIN_HEIGHT` resta solo come ripiego se MAX non è popolata.
     *
     * Al primo bind il bundle può essere vuoto (tutte le chiavi a 0) e alcuni
     * OEM riportano valori incoerenti: in quel caso torniamo un'altezza che
     * produce [FALLBACK_ROWS] righe invece di un widget vuoto.
     */
    private fun availableHeightDp(
        manager: AppWidgetManager,
        appWidgetId: Int,
    ): Int {
        val options: Bundle = try {
            manager.getAppWidgetOptions(appWidgetId)
        } catch (_: Exception) {
            return fallbackHeightDp()
        }
        val reported = options
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            .takeIf { it > 0 }
            ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if (reported <= 0) return fallbackHeightDp()
        return reported - HEIGHT_SAFETY_DP
    }

    private fun fallbackHeightDp(): Int =
        UsageWidgetModel.ROOT_VPADDING_DP +
            UsageWidgetModel.HEADER_DP +
            FALLBACK_ROWS * UsageWidgetModel.LIMIT_ROW_DP

    /**
     * Tap sul widget → Koru sulla schermata Statistiche.
     *
     * `FLAG_IMMUTABLE` incondizionato (esiste da API 23, obbligatorio da 31).
     * `data` con uno schema custom perché l'uguaglianza fra PendingIntent
     * IGNORA gli extra: due PendingIntent che differiscono solo per un extra
     * verrebbero collassati nello stesso oggetto, e il secondo lancerebbe il
     * payload del primo.
     */
    private fun openStatsIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("koru://widget/stats")
            putExtra(KoruUsageWidgetProvider.EXTRA_WIDGET_ROUTE, ROUTE_STATS)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context,
            REQUEST_OPEN_STATS,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Schermata di sistema per concedere l'usage access.
     *
     * `getActivity` (non `getBroadcast`): è il launcher, già in foreground, a
     * lanciare l'Activity — passare da un receiver incapperebbe nel blocco dei
     * background activity launch di Android 12+.
     *
     * L'intent viene RISOLTO e PUNTATO sul package che lo gestisce invece di
     * restare implicito. Due motivi: (1) un'app terza può dichiarare un
     * intent-filter sulla stessa action e finire nel disambiguation dialog al
     * posto delle impostazioni vere; (2) su alcuni OEM la schermata non esiste
     * e un intent implicito irrisolvibile fa fallire il tap con
     * `ActivityNotFoundException` dentro il processo del launcher. Se non si
     * risolve, ripieghiamo su Koru: l'utente atterra nell'app, dove il flusso
     * permessi esistente lo guida.
     */
    private fun usageAccessSettingsIntent(context: Context): PendingIntent {
        val settings = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val resolvedPackage = try {
            context.packageManager.resolveActivity(settings, 0)?.activityInfo?.packageName
        } catch (_: Exception) {
            null
        }
        val target = if (resolvedPackage != null) {
            settings.setPackage(resolvedPackage)
        } else {
            Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("koru://widget/permission")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        }
        return PendingIntent.getActivity(
            context,
            REQUEST_USAGE_ACCESS,
            target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /// Route Flutter aperta dal tap sul widget (mirror di `KoruRoutes.stats`).
    const val ROUTE_STATS = "/stats"

    private const val REQUEST_OPEN_STATS = 9101
    private const val REQUEST_USAGE_ACCESS = 9102
}
