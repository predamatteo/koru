package com.dev.koru.widget

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Log
import com.dev.koru.channels.PermissionMethodChannel
import com.dev.koru.inventory.PackageInventory
import com.dev.koru.inventory.PackageVisibility
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.ReelCountStore
import com.dev.koru.service.UsageCounter
import java.util.Calendar

/**
 * Raccoglie i dati che il widget mostra: uso di oggi ([UsageCounter]), limiti
 * giornalieri ([AppUsageLimitsStore]) e label/icone dal PackageManager.
 *
 * COSTO — questa classe fa l'unica operazione pesante del widget: una passata
 * di `UsageStatsManager.queryEvents` su tutta la giornata (la stessa che usa la
 * schermata Statistiche). **Non va MAI chiamata dal main thread**: il widget
 * vive nel processo main, condiviso con la UI Flutter, e una query di 100-300ms
 * lì sarebbe jank visibile. Il chiamante è [KoruUsageWidgetProvider], che gira
 * sempre sul suo worker dedicato.
 *
 * Legge lo stato con [UsageCounter.foregroundMsPerPackage] (versione NON
 * guardata): è una vista, non enforcement, e la variante guardata avrebbe
 * l'effetto collaterale di scrivere su [com.dev.koru.service.UsageGuardStore] —
 * stessa scelta fatta dalle card in-app.
 */
internal object UsageWidgetDataSource {

    private const val TAG = "UsageWidget"

    /// Quanti package al massimo risolviamo dal PackageManager. Le righe
    /// visibili sono al più [UsageWidgetModel.MAX_ROWS], ma ne risolviamo di
    /// più perché il filtro "launchable" può scartarne diversi: senza margine
    /// un widget alto resterebbe con meno righe del dovuto.
    private const val LABEL_RESOLUTION_BUDGET = 40

    /**
     * Snapshot completo pronto per il rendering, oppure `null` se manca il
     * permesso di usage access.
     *
     * Il null NON è un dettaglio: `PACKAGE_USAGE_STATS` è una appops
     * permission e senza concessione `queryEvents` **non lancia**, ritorna una
     * lista vuota. Renderizzare quel vuoto darebbe "0m" su tutto, cioè un
     * widget che mente. Il check esplicito ([PermissionMethodChannel.hasUsageStats])
     * permette al renderer di mostrare invece lo stato "concedi l'accesso".
     */
    fun snapshot(context: Context): UsageWidgetModel.Snapshot? {
        if (!PermissionMethodChannel.hasUsageStats(context)) return null
        val rawUsage = todayUsageMs(context) ?: return null
        val limits = AppUsageLimitsStore.read(context)
            .mapValues { (_, e) -> UsageWidgetModel.LimitSpec(e.minutes, e.strict) }

        // Il filtro si applica alla MAPPA, non solo alle righe: così il totale
        // è la somma di quello che il widget mostra, e coincide per costruzione
        // con lo screen time della schermata Statistiche — che passa dallo
        // stesso predicato in `UsageStatsCallHandler`. Prima il totale era
        // grezzo apposta, per allinearsi a un provider Dart che non filtrava:
        // ora filtrano entrambi, quindi la divergenza non serve più.
        val usage = PackageVisibility.filterUserFacing(
            usage = rawUsage,
            selfPackage = context.packageName,
            launchablePackages = PackageInventory.launchablePackages(context),
            homePackages = PackageInventory.homePackages(context),
            skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
        )

        // Le righe partono già da `usage` filtrata; `excludedPackages` copre i
        // soli package che entrano da `limits` (un cap impostato su un'app poi
        // diventata launcher predefinito, per dire) e non passano dalla mappa.
        val excluded = KoruAccessibilityService.SKIP_PACKAGES +
            context.packageName +
            PackageInventory.homePackages(context)
        val labels = resolveLabels(
            context = context,
            packages = candidatePackages(usage, limits.keys, excluded),
        )

        return UsageWidgetModel.Snapshot(
            totalMs = UsageWidgetModel.totalMs(usage),
            rows = UsageWidgetModel.buildRows(
                usageMs = usage,
                limits = limits,
                labels = labels,
                excludedPackages = excluded,
            ),
            // Lettura cache-ata di un file di poche centinaia di byte, che
            // include già i conteggi non ancora versati su disco: nessun flush
            // qui: aggiungerebbe una scrittura al percorso di rendering, e il
            // widget gira nello stesso processo che tiene quel buffer.
            reelsToday = ReelCountStore.todayTotal(context),
        )
    }

    /// Foreground di oggi per package, dalla mezzanotte locale a ora. `null` se
    /// `UsageStatsManager` non risponde (permesso PACKAGE_USAGE_STATS mancante).
    private fun todayUsageMs(context: Context): Map<String, Long>? {
        val dayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        return try {
            UsageCounter.foregroundMsPerPackage(context, dayStart, System.currentTimeMillis())
        } catch (e: Exception) {
            Log.w(TAG, "UsageStats non disponibile per il widget", e)
            null
        }
    }

    /// I soli package per cui vale la pena pagare una risoluzione label: tutti
    /// quelli con un limite (devono comparire anche a 0 minuti) più i più usati
    /// di oggi. Risolvere le label di TUTTE le app installate costerebbe
    /// secondi (vedi la nota PERF in `AppInventoryCallHandler`).
    private fun candidatePackages(
        usage: Map<String, Long>,
        limitPackages: Set<String>,
        excluded: Set<String>,
    ): Set<String> {
        val topUsed = usage.entries
            .filter { it.value >= UsageWidgetModel.MIN_PLAIN_ROW_MS }
            .sortedByDescending { it.value }
            .take(LABEL_RESOLUTION_BUDGET)
            .map { it.key }
        return (limitPackages + topUsed) - excluded
    }

    /**
     * Label dei [packages] installati E apribili dal drawer. Il criterio
     * "launchable" (activity MAIN + CATEGORY_LAUNCHER) arriva da
     * [PackageInventory], la stessa sorgente che alimenta il filtro delle
     * statistiche e del drawer: senza, il widget mostrerebbe componenti Play,
     * IME e servizi che accumulano foreground ma non sono app che l'utente
     * riconosce.
     *
     * FAIL-OPEN: se la query launchable non restituisce nulla (fallimento del
     * PackageManager, non "zero app launchable" che è impossibile su un device
     * reale) il filtro viene disattivato e teniamo tutti i package installati —
     * meglio una riga di troppo che un widget vuoto. Stessa postura difensiva
     * del `filterActive` di `TodayLimitsCard`.
     */
    private fun resolveLabels(context: Context, packages: Set<String>): Map<String, String> {
        val pm = context.packageManager
        val launchable = PackageInventory.launchablePackages(context)
        val out = HashMap<String, String>(packages.size)
        for (pkg in packages) {
            if (launchable.isNotEmpty() && pkg !in launchable) continue
            labelCached(pm, pkg)?.let { out[pkg] = it }
        }
        return out
    }

    // ── Cache delle label ──────────────────────────────────────────────────
    // `getApplicationLabel` costringe il framework ad aprire le risorse
    // dell'APK bersaglio, e il widget si ridisegna anche ogni 30s mentre il
    // set di app installate cambia forse una volta a settimana. La cache dei
    // due SET di package (launchable/home) è salita in [PackageInventory],
    // condivisa con le statistiche e col drawer; qui resta solo la mappa
    // package → label, che è specifica del widget.
    private val labelCache = HashMap<String, String>()

    /// `null` = package non installato (o label non leggibile): il chiamante lo
    /// scarta, che è anche il filtro dei limiti orfani.
    private fun labelCached(pm: PackageManager, pkg: String): String? {
        labelCache[pkg]?.let { return it }
        val label = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            return null // app disinstallata: il limite orfano non va mostrato
        } catch (e: Exception) {
            Log.w(TAG, "label non risolvibile per $pkg", e)
            return null
        }
        labelCache[pkg] = label
        return label
    }

    /// Cache LRU delle icone già rasterizzate. Due motivi, entrambi misurabili:
    /// (1) `getApplicationIcon` + rasterizzazione di un AdaptiveIconDrawable
    /// costa quanto la query UsageStats, e il widget si ridisegna spesso;
    /// (2) `RemoteViews` deduplica i bitmap nella transazione Binder solo per
    /// IDENTITÀ di istanza — riusare lo stesso oggetto riduce davvero il
    /// payload verso il launcher, ricrearlo uguale no.
    private const val ICON_CACHE_MAX = 24
    private val iconCache = object : LinkedHashMap<String, Bitmap>(
        ICON_CACHE_MAX, 0.75f, true,
    ) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Bitmap>): Boolean =
            size > ICON_CACHE_MAX
    }

    /// Svuota tutte le cache (icone + label + inventario PackageManager).
    /// Chiamata quando l'ultimo widget viene rimosso: senza, i bitmap
    /// resterebbero appesi al processo main per sempre.
    @Synchronized
    fun clearCaches() {
        iconCache.clear()
        labelCache.clear()
        PackageInventory.clearCaches()
    }

    /**
     * Icona dell'app come [Bitmap] quadrata di [sizePx] lato, pronta per
     * `RemoteViews.setImageViewBitmap`. Le icone adattive non sono
     * [BitmapDrawable], quindi vanno disegnate su canvas.
     *
     * [sizePx] è in PIXEL, mai in dp: rasterizzare a `40dp` su un device
     * xxhdpi darebbe 120px di lato (~58KB per icona) e con una manciata di
     * righe la RemoteViews supererebbe il buffer Binder da 1MB condiviso col
     * resto del processo → `TransactionTooLargeException` lato launcher.
     */
    @Synchronized
    fun iconBitmap(context: Context, packageName: String, sizePx: Int): Bitmap? {
        val size = sizePx.coerceIn(24, 128)
        val key = "$packageName@$size"
        iconCache[key]?.let { if (!it.isRecycled) return it }
        val bitmap = renderIcon(context, packageName, size) ?: return null
        iconCache[key] = bitmap
        return bitmap
    }

    private fun renderIcon(context: Context, packageName: String, size: Int): Bitmap? {
        val drawable: Drawable = try {
            context.packageManager.getApplicationIcon(packageName)
        } catch (_: Exception) {
            return null
        }
        // SEMPRE via canvas, anche per un BitmapDrawable: riusare il bitmap
        // sorgente sarebbe più veloce ma può avere `Config.HARDWARE`, che NON
        // è parcellizzabile — finirebbe in una RemoteViews che il launcher non
        // riesce a leggere. Disegnare su un ARGB_8888 nostro chiude il caso, e
        // il costo si paga una volta sola grazie alla cache.
        return try {
            val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            out
        } catch (e: Exception) {
            Log.w(TAG, "icona non renderizzabile per $packageName", e)
            null
        }
    }
}
