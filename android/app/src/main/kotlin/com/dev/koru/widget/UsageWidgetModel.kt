package com.dev.koru.widget

/**
 * Modello **puro** del widget home "tempo d'uso + limiti": nessuna dipendenza
 * Android, così l'ordinamento, il formatting e il fitting delle righe sono
 * testabili in JVM senza Robolectric (stesso pattern di
 * [com.dev.koru.service.WatchedPackageCalculator] e
 * [com.dev.koru.service.BlockPolicyEvaluator]).
 *
 * PARITÀ CON LA UI FLUTTER — il widget e l'app devono mostrare gli STESSI
 * numeri, altrimenti l'utente vede due verità sullo stesso dato:
 *  - `formatDurationMs` è il porting 1:1 di `_fmtDurationMs`
 *    (`lib/presentation/screens/statistics/statistics_screen.dart`): ms → minuti
 *    con **round** (non floor), poi `Xh Ym` / `Xh` / `Ym`.
 *  - `toMinutes` replica `usageTodayMinutesProvider`
 *    (`lib/presentation/providers/app_limits_provider.dart`): `(ms / 60000).round()`.
 *  - [barStateFor] replica la scelta colore di `_LimitRow`
 *    (`lib/presentation/screens/home/widgets/today_limits_card.dart`):
 *    `used >= cap` → danger, `used/cap > 0.8` → sand, altrimenti sage.
 *
 * ── DUE DIVERGENZE INTENZIONALI (non regressioni: leggile prima di "aggiustarle") ──
 *
 * 1. **Totale grezzo, righe filtrate.** Il totale è la somma di TUTTI i package
 *    con uso > 0, esattamente come `periodScreenTimeMsProvider` (che non filtra
 *    nulla). Le righe invece escludono launcher/systemui/Koru: sono voci su cui
 *    l'utente non può agire e, con Koru impostato come launcher di default,
 *    occuperebbero stabilmente il primo posto. Conseguenza da conoscere: su un
 *    device in cui Koru È il launcher, il totale include il tempo di Koru e può
 *    quindi essere molto più grande della somma delle righe visibili.
 *    Il compromesso è deliberato — è lo stesso schema del widget Digital
 *    Wellbeing (totale + top app che non sommano al totale) — e privilegia
 *    l'invariante più importante: **il numero del widget e quello della
 *    schermata Statistiche devono coincidere**. Filtrare anche il totale
 *    renderebbe il widget internamente coerente ma in disaccordo con l'app,
 *    cioè un bug che l'utente non può diagnosticare.
 *
 * 2. **Contatore NON guardato.** L'enforcement del cap usa
 *    `UsageCounter.guardedTodayForegroundMs` (con la guardia monotonica
 *    anti clock-backward di `UsageGuardStore`); il widget usa la variante
 *    grezza. Non è una svista: la card `TodayLimitsCard` in-app fa lo stesso,
 *    e la variante guardata ha un side-effect di SCRITTURA cross-process che
 *    una vista non deve avere. Dopo uno spostamento dell'orologio all'indietro
 *    widget e card mostrano entrambi meno minuti di quelli su cui
 *    l'enforcement decide — divergenza app-vs-enforcement PREESISTENTE, non
 *    introdotta qui. Allinearla è un lavoro da fare su entrambe le viste
 *    insieme, non solo sul widget (che altrimenti divergerebbe dalla card).
 */
object UsageWidgetModel {

    /// Stato visivo della barra used/cap. Tre livelli invece di due perché la
    /// UI Flutter distingue "vicino al cap" (sabbia) da "sotto" (salvia): senza
    /// il livello intermedio il widget perderebbe il segnale di avvicinamento.
    enum class BarState { UNDER, NEAR, OVER }

    /// Limite giornaliero per un package. Copia minima di
    /// `AppUsageLimitsStore.LimitEntry` per tenere questo file libero da
    /// dipendenze verso store che richiedono un `Context`.
    data class LimitSpec(val minutes: Int, val strict: Boolean)

    /// Una riga del widget. `limitMinutes == null` ⇒ app senza time limit
    /// (mostrata solo per il tempo d'uso, senza barra).
    data class Row(
        val packageName: String,
        val label: String,
        val usedMs: Long,
        val limitMinutes: Int?,
        val strict: Boolean,
    ) {
        val hasLimit: Boolean get() = limitMinutes != null && limitMinutes > 0
    }

    /// Snapshot completo renderizzato dal widget.
    data class Snapshot(
        val totalMs: Long,
        val rows: List<Row>,
    )

    // ── Altezze (dp) usate per decidere quante righe entrano ────────────────
    // Misurate sui layout reali, non stimate a occhio. Una riga con barra costa
    // più di una riga semplice, quindi il fitting le conta separatamente invece
    // di usare un'altezza media (che su un widget pieno di limiti troncherebbe).
    //
    //   widget_usage.xml       paddingVertical 14dp × 2               → 28
    //   header                 pill 16sp (~19) + 4+4 + margin 10      → 38
    //   row_limit              5 + icona/label 20 + 5 + barra 6 + 5   → 41
    //   row_plain              5 + icona/label 20 + 5                 → 30
    //
    // Il restyle M3 Expressive ha alzato icone (18→20dp) e barra (5→6dp): i
    // padding sono stati stretti in proporzione (6→5, header 12→10) perché il
    // costo per riga restasse quasi invariato. Non è pignoleria: a +6dp per
    // riga un widget 4x2 sarebbe passato da 2 righe a 1, cioè il restyle
    // avrebbe tolto informazione — che è il modo più facile di rendere un
    // widget più bello e meno utile.
    //
    // [ROOT_VPADDING_DP] esisteva solo implicitamente ed era il bug: il budget
    // veniva calcolato sull'altezza totale del widget senza scalare il padding
    // del root, quindi l'ultima riga finiva fuori dal contenitore e veniva
    // tagliata a metà (tipicamente la barra di progresso).
    internal const val ROOT_VPADDING_DP = 28
    internal const val HEADER_DP = 38
    internal const val LIMIT_ROW_DP = 41
    internal const val PLAIN_ROW_DP = 30

    /// Tetto duro al numero di righe. Ogni riga porta una bitmap d'icona nella
    /// transazione Binder verso il launcher: RemoteViews troppo grandi vengono
    /// rifiutate (`TransactionTooLargeException` lato host). 8 righe × icona
    /// 48px ARGB_8888 (~9KB) ≈ 75KB, ampiamente sotto il limite pratico.
    internal const val MAX_ROWS = 8

    /// Un'app SENZA limite entra nella lista solo se il suo tempo arrotonda ad
    /// almeno 1 minuto: sotto i 30s renderizzerebbe "0m", che è rumore. Le app
    /// CON limite sono sempre incluse anche a 0 minuti — "0m / 30m" è
    /// informazione utile, non rumore.
    internal const val MIN_PLAIN_ROW_MS = 30_000L

    /**
     * Costruisce le righe candidate in ordine di priorità:
     *  1. app con time limit, per rapporto used/cap DECRESCENTE (quelle vicine
     *     o oltre il cap devono restare visibili anche sul widget più piccolo);
     *  2. app senza limite, per tempo d'uso decrescente.
     * A parità, ordine alfabetico sul label per rendere il risultato
     * deterministico (i test lo verificano; senza tie-break l'ordine dipende
     * dall'iterazione della mappa).
     *
     * @param usageMs tempo di foreground di oggi per package (già filtrato > 0
     *   dal chiamante o meno: qui i valori <= 0 sono trattati come 0).
     * @param limits limiti giornalieri attivi, già letti dallo store.
     * @param labels label risolte dal PackageManager; un package assente è
     *   considerato NON installato e viene scartato (i limiti orfani di app
     *   disinstallate non devono comparire — stesso filtro di `TodayLimitsCard`).
     * @param excludedPackages launcher/systemui/Koru: esclusi dalle righe, non
     *   dal totale (vedi nota di classe).
     */
    fun buildRows(
        usageMs: Map<String, Long>,
        limits: Map<String, LimitSpec>,
        labels: Map<String, String>,
        excludedPackages: Set<String>,
    ): List<Row> {
        val limited = ArrayList<Row>()
        val plain = ArrayList<Row>()

        for ((pkg, spec) in limits) {
            if (spec.minutes <= 0) continue
            if (pkg in excludedPackages) continue
            val label = labels[pkg] ?: continue // app disinstallata → limite orfano
            limited.add(
                Row(
                    packageName = pkg,
                    label = label,
                    usedMs = usageMs[pkg]?.coerceAtLeast(0L) ?: 0L,
                    limitMinutes = spec.minutes,
                    strict = spec.strict,
                ),
            )
        }

        for ((pkg, ms) in usageMs) {
            if (ms < MIN_PLAIN_ROW_MS) continue
            if (pkg in excludedPackages) continue
            if (limits[pkg]?.let { it.minutes > 0 } == true) continue // già in `limited`
            val label = labels[pkg] ?: continue
            plain.add(
                Row(
                    packageName = pkg,
                    label = label,
                    usedMs = ms,
                    limitMinutes = null,
                    strict = false,
                ),
            )
        }

        limited.sortWith(
            compareByDescending<Row> { usedRatio(it) }
                .thenByDescending { it.usedMs }
                .thenBy { it.label.lowercase() },
        )
        plain.sortWith(
            compareByDescending<Row> { it.usedMs }.thenBy { it.label.lowercase() },
        )

        return limited + plain
    }

    /// Somma grezza del tempo di foreground di oggi — parità con
    /// `periodScreenTimeMsProvider` lato Flutter, che NON filtra alcun package.
    fun totalMs(usageMs: Map<String, Long>): Long =
        usageMs.values.sumOf { it.coerceAtLeast(0L) }

    /**
     * Quante delle [candidates] entrano in un widget alto [heightDp], scalando
     * per il costo reale di ciascun tipo di riga. Ritorna sempre almeno 1
     * quando c'è almeno una candidata: su un widget schiacciato è meglio una
     * riga tagliata che un widget vuoto.
     */
    fun rowsFittingHeight(heightDp: Int, candidates: List<Row>): Int {
        if (candidates.isEmpty()) return 0
        var budget = heightDp - ROOT_VPADDING_DP - HEADER_DP
        var count = 0
        for (row in candidates) {
            val cost = if (row.hasLimit) LIMIT_ROW_DP else PLAIN_ROW_DP
            if (budget < cost) break
            budget -= cost
            count++
            if (count >= MAX_ROWS) break
        }
        return count.coerceAtLeast(1).coerceAtMost(minOf(candidates.size, MAX_ROWS))
    }

    /// ms → minuti come la UI Flutter (`(ms / 60000).round()`), non `/ 60000`
    /// intero: con il troncamento il widget mostrerebbe un minuto in meno
    /// dell'app per oltre metà del tempo.
    ///
    /// Il clamp a 0 rende la funzione TOTALE. Il porting è fedele solo sui non
    /// negativi: Dart `round()` arrotonda i mezzi lontano dallo zero e `%` è
    /// euclideo, `Math.round` arrotonda verso +∞ e `%` in Kotlin è troncato —
    /// su input negativi i due lati divergerebbero. Oggi un tempo di foreground
    /// negativo non è raggiungibile (i chiamanti coercono già a 0), ma
    /// affidarsi a quell'invariante a distanza è fragile: meglio chiudere il
    /// caso qui che lasciare una bomba a orologeria in un formatter.
    fun toMinutes(ms: Long): Int = Math.round(ms.coerceAtLeast(0L) / 60_000.0).toInt()

    /// Porting 1:1 di `_fmtDurationMs` (statistics_screen.dart).
    fun formatDurationMs(ms: Long): String {
        val totalMinutes = toMinutes(ms)
        val h = totalMinutes / 60
        val m = totalMinutes % 60
        return when {
            h == 0 -> "${m}m"
            m == 0 -> "${h}h"
            else -> "${h}h ${m}m"
        }
    }

    /// Testo "usato / cap" della riga con limite, in minuti come `_LimitRow`.
    fun formatUsedOverCap(usedMs: Long, limitMinutes: Int): String =
        "${toMinutes(usedMs)} / $limitMinutes min"

    /// Percentuale 0..100 per la ProgressBar (clampata come `progress` in Dart).
    fun progressPercent(usedMs: Long, limitMinutes: Int): Int {
        if (limitMinutes <= 0) return 0
        val ratio = toMinutes(usedMs).toDouble() / limitMinutes
        return (ratio * 100).toInt().coerceIn(0, 100)
    }

    /// Colore della barra, allineato a `_LimitRow`: il confronto "superato" è
    /// sui MINUTI (`used >= cap`), non sui ms — così widget e card in-app
    /// diventano rossi nello stesso istante.
    fun barStateFor(usedMs: Long, limitMinutes: Int): BarState {
        if (limitMinutes <= 0) return BarState.UNDER
        val used = toMinutes(usedMs)
        if (used >= limitMinutes) return BarState.OVER
        return if (used.toDouble() / limitMinutes > 0.8) BarState.NEAR else BarState.UNDER
    }

    /// Rapporto used/cap NON clampato: usato solo per l'ordinamento, così
    /// un'app al 300% del cap resta sopra a una al 100%.
    private fun usedRatio(row: Row): Double {
        val cap = row.limitMinutes ?: return 0.0
        if (cap <= 0) return 0.0
        return toMinutes(row.usedMs).toDouble() / cap
    }
}
