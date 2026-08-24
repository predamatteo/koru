package com.dev.koru.widget

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [UsageWidgetModel]. Due famiglie di proprietà:
 *
 *  1. **Parità con la UI Flutter** — il widget e l'app leggono gli stessi dati
 *     ma li formattano in due linguaggi diversi. Questi test sono l'unico
 *     posto in cui la traduzione è verificata: se qualcuno cambia
 *     `_fmtDurationMs` in `statistics_screen.dart` senza toccare il Kotlin,
 *     l'utente vede due numeri diversi per lo stesso minuto.
 *  2. **Ordinamento e fitting** — la riga che conta (app oltre il cap) deve
 *     restare visibile anche sul widget più piccolo.
 */
class UsageWidgetModelTest {

    private val IG = "com.instagram.android"
    private val YT = "com.google.android.youtube"
    private val WA = "com.whatsapp"
    private val TK = "com.zhiliaoapp.musically"
    private val KORU = "com.dev.koru"
    private val SYSTEMUI = "com.android.systemui"

    private val labels = mapOf(
        IG to "Instagram",
        YT to "YouTube",
        WA to "WhatsApp",
        TK to "TikTok",
        KORU to "Koru",
        SYSTEMUI to "System UI",
    )

    private fun min(m: Int): Long = m * 60_000L

    private fun rows(
        usage: Map<String, Long> = emptyMap(),
        limits: Map<String, UsageWidgetModel.LimitSpec> = emptyMap(),
        excluded: Set<String> = emptySet(),
        knownLabels: Map<String, String> = labels,
    ) = UsageWidgetModel.buildRows(usage, limits, knownLabels, excluded)

    // ── Formatting: parità con _fmtDurationMs (statistics_screen.dart) ──────

    @Test
    fun formatsHoursAndMinutes() {
        assertThat(UsageWidgetModel.formatDurationMs(min(192))).isEqualTo("3h 12m")
    }

    @Test
    fun formatsMinutesOnlyBelowOneHour() {
        assertThat(UsageWidgetModel.formatDurationMs(min(45))).isEqualTo("45m")
    }

    @Test
    fun omitsZeroMinutesOnWholeHours() {
        // Il Dart ritorna "2h", MAI "2h 0m".
        assertThat(UsageWidgetModel.formatDurationMs(min(120))).isEqualTo("2h")
    }

    @Test
    fun roundsMinutesInsteadOfTruncating() {
        // 90s → 1.5 min → round = 2. Con il troncamento sarebbe "1m" e il
        // widget mostrerebbe un minuto meno dell'app per oltre metà del tempo.
        assertThat(UsageWidgetModel.formatDurationMs(90_000L)).isEqualTo("2m")
        assertThat(UsageWidgetModel.toMinutes(90_000L)).isEqualTo(2)
        assertThat(UsageWidgetModel.toMinutes(29_000L)).isEqualTo(0)
    }

    @Test
    fun formatsZero() {
        assertThat(UsageWidgetModel.formatDurationMs(0L)).isEqualTo("0m")
    }

    @Test
    fun formatsUsedOverCapInMinutes() {
        assertThat(UsageWidgetModel.formatUsedOverCap(min(42), 60)).isEqualTo("42 / 60 min")
    }

    // ── Stato barra: parità con _LimitRow (today_limits_card.dart) ──────────

    @Test
    fun barIsOverWhenUsedEqualsCap() {
        // Il Dart usa `used >= limit`: esattamente al cap è già "superato".
        assertThat(UsageWidgetModel.barStateFor(min(30), 30))
            .isEqualTo(UsageWidgetModel.BarState.OVER)
    }

    @Test
    fun barIsNearAboveEightyPercent() {
        // 25/30 = 0.833 > 0.8 → sabbia.
        assertThat(UsageWidgetModel.barStateFor(min(25), 30))
            .isEqualTo(UsageWidgetModel.BarState.NEAR)
    }

    @Test
    fun barIsUnderAtExactlyEightyPercent() {
        // Il Dart usa `> 0.8` stretto: 24/30 = 0.8 resta salvia.
        assertThat(UsageWidgetModel.barStateFor(min(24), 30))
            .isEqualTo(UsageWidgetModel.BarState.UNDER)
    }

    @Test
    fun progressIsClampedAtHundred() {
        assertThat(UsageWidgetModel.progressPercent(min(90), 30)).isEqualTo(100)
        assertThat(UsageWidgetModel.progressPercent(min(15), 30)).isEqualTo(50)
        assertThat(UsageWidgetModel.progressPercent(min(15), 0)).isEqualTo(0)
    }

    // ── Totale ─────────────────────────────────────────────────────────────

    @Test
    fun totalSumsEveryPackageIncludingSystemOnes() {
        // Parità con periodScreenTimeMsProvider, che NON filtra: se il widget
        // filtrasse, mostrerebbe un totale diverso dalla schermata Statistiche.
        val total = UsageWidgetModel.totalMs(
            mapOf(IG to min(40), KORU to min(20), SYSTEMUI to min(5)),
        )
        assertThat(total).isEqualTo(min(65))
    }

    // ── Ordinamento ────────────────────────────────────────────────────────

    @Test
    fun limitedAppsComeBeforeUnlimitedOnes() {
        val out = rows(
            usage = mapOf(WA to min(120), IG to min(5)),
            limits = mapOf(IG to UsageWidgetModel.LimitSpec(60, false)),
        )
        // WhatsApp ha 2 ore contro i 5 minuti di Instagram, ma Instagram ha un
        // cap: è la riga su cui l'utente può agire.
        assertThat(out.map { it.packageName }).containsExactly(IG, WA).inOrder()
    }

    @Test
    fun limitedAppsSortedByRatioNotByAbsoluteTime() {
        val out = rows(
            usage = mapOf(IG to min(50), YT to min(20)),
            limits = mapOf(
                IG to UsageWidgetModel.LimitSpec(120, false), // 42%
                YT to UsageWidgetModel.LimitSpec(25, true), // 80%
            ),
        )
        assertThat(out.map { it.packageName }).containsExactly(YT, IG).inOrder()
    }

    @Test
    fun exceededAppRanksAboveAppAtExactlyTheCap() {
        // Il rapporto NON è clampato per l'ordinamento: 300% deve battere 100%.
        val out = rows(
            usage = mapOf(IG to min(90), YT to min(30)),
            limits = mapOf(
                IG to UsageWidgetModel.LimitSpec(30, false), // 300%
                YT to UsageWidgetModel.LimitSpec(30, false), // 100%
            ),
        )
        assertThat(out.first().packageName).isEqualTo(IG)
    }

    @Test
    fun unlimitedAppsSortedByUsageDescending() {
        val out = rows(usage = mapOf(WA to min(10), YT to min(40), TK to min(25)))
        assertThat(out.map { it.packageName }).containsExactly(YT, TK, WA).inOrder()
    }

    // ── Filtri ─────────────────────────────────────────────────────────────

    @Test
    fun limitedAppIsShownEvenWithZeroUsage() {
        // "0 / 30 min" è informazione utile: dice che il budget è intatto.
        val out = rows(limits = mapOf(IG to UsageWidgetModel.LimitSpec(30, true)))
        assertThat(out).hasSize(1)
        assertThat(out.first().usedMs).isEqualTo(0L)
        assertThat(out.first().hasLimit).isTrue()
    }

    @Test
    fun unlimitedAppBelowOneMinuteIsDropped() {
        // 20s arrotonderebbe a "0m": rumore, non informazione.
        val out = rows(usage = mapOf(WA to 20_000L, YT to min(3)))
        assertThat(out.map { it.packageName }).containsExactly(YT)
    }

    @Test
    fun orphanLimitOfUninstalledAppIsDropped() {
        // koru_app_limits.json può contenere package disinstallati finché il
        // cleanup async non passa: la label assente è il segnale di "non
        // installata", stesso filtro di TodayLimitsCard.
        val out = rows(
            limits = mapOf("com.gone.app" to UsageWidgetModel.LimitSpec(30, true)),
            knownLabels = labels,
        )
        assertThat(out).isEmpty()
    }

    @Test
    fun excludedPackagesNeverBecomeRows() {
        // Con Koru impostato come launcher di default sarebbe stabilmente la
        // prima riga per tempo d'uso — inutile e fuorviante.
        val out = rows(
            usage = mapOf(KORU to min(200), SYSTEMUI to min(30), YT to min(10)),
            excluded = setOf(KORU, SYSTEMUI),
        )
        assertThat(out.map { it.packageName }).containsExactly(YT)
    }

    @Test
    fun excludedPackageIsDroppedEvenIfItHasALimit() {
        val out = rows(
            usage = mapOf(KORU to min(50)),
            limits = mapOf(KORU to UsageWidgetModel.LimitSpec(30, true)),
            excluded = setOf(KORU),
        )
        assertThat(out).isEmpty()
    }

    @Test
    fun zeroMinuteLimitIsTreatedAsNoLimit() {
        // Lo store filtra già `minutes <= 0`, ma un file scritto a mano può
        // contenerli: non devono creare una riga con barra su cap zero.
        val out = rows(
            usage = mapOf(IG to min(10)),
            limits = mapOf(IG to UsageWidgetModel.LimitSpec(0, true)),
        )
        assertThat(out).hasSize(1)
        assertThat(out.first().hasLimit).isFalse()
    }

    @Test
    fun appWithLimitIsNotDuplicatedInPlainRows() {
        val out = rows(
            usage = mapOf(IG to min(10)),
            limits = mapOf(IG to UsageWidgetModel.LimitSpec(30, true)),
        )
        assertThat(out).hasSize(1)
    }

    @Test
    fun orderIsDeterministicOnTies() {
        // Senza tie-break l'ordine dipenderebbe dall'iterazione della mappa.
        val usage = mapOf(YT to min(10), WA to min(10), TK to min(10))
        val first = rows(usage = usage).map { it.packageName }
        val second = rows(usage = usage).map { it.packageName }
        assertThat(first).isEqualTo(second)
        assertThat(first).containsExactly(TK, WA, YT).inOrder() // TikTok < WhatsApp < YouTube
    }

    // ── Fitting sull'altezza ───────────────────────────────────────────────

    @Test
    fun tallWidgetFitsMoreRowsThanShortOne() {
        val candidates = List(8) {
            UsageWidgetModel.Row("pkg$it", "App $it", min(10), null, false)
        }
        val short = UsageWidgetModel.rowsFittingHeight(110, candidates) // ~4x2
        val tall = UsageWidgetModel.rowsFittingHeight(250, candidates) // ~4x4
        assertThat(tall).isGreaterThan(short)
        assertThat(short).isAtLeast(1)
    }

    @Test
    fun limitedRowsCostMoreHeightThanPlainRows() {
        val plain = List(6) {
            UsageWidgetModel.Row("p$it", "Plain $it", min(10), null, false)
        }
        val limited = List(6) {
            UsageWidgetModel.Row("l$it", "Limited $it", min(10), 30, false)
        }
        val h = 180
        assertThat(UsageWidgetModel.rowsFittingHeight(h, plain))
            .isGreaterThan(UsageWidgetModel.rowsFittingHeight(h, limited))
    }

    @Test
    fun neverReturnsZeroRowsWhenCandidatesExist() {
        // Widget schiacciato sotto l'altezza dell'header: meglio una riga
        // tagliata che un widget vuoto.
        val candidates = listOf(
            UsageWidgetModel.Row(IG, "Instagram", min(10), 30, true),
        )
        assertThat(UsageWidgetModel.rowsFittingHeight(20, candidates)).isEqualTo(1)
    }

    @Test
    fun returnsZeroRowsWithoutCandidates() {
        assertThat(UsageWidgetModel.rowsFittingHeight(400, emptyList())).isEqualTo(0)
    }

    @Test
    fun budgetAccountsForRootPaddingAndHeader_regression() {
        // Regressione: il budget veniva calcolato senza scalare i 28dp di
        // padding verticale del root, quindi l'ultima riga finiva fuori dal
        // contenitore e la sua barra di progresso veniva tagliata.
        // Altezza costruita per contenere ESATTAMENTE 2 righe con barra.
        val candidates = List(4) {
            UsageWidgetModel.Row("pkg$it", "App $it", min(10), 30, false)
        }
        val exactlyTwo = UsageWidgetModel.ROOT_VPADDING_DP +
            UsageWidgetModel.HEADER_DP +
            2 * UsageWidgetModel.LIMIT_ROW_DP
        assertThat(UsageWidgetModel.rowsFittingHeight(exactlyTwo, candidates)).isEqualTo(2)
        // Un solo dp in meno e la terza riga non deve comparire (né la seconda
        // sforare): il fitting è esatto, non ottimista.
        assertThat(
            UsageWidgetModel.rowsFittingHeight(exactlyTwo - 1, candidates),
        ).isEqualTo(1)
    }

    @Test
    fun toMinutesClampsNegativeInput() {
        // Il porting è fedele solo sui non negativi (Dart arrotonda i mezzi
        // lontano dallo zero e usa `%` euclideo). Il clamp rende la funzione
        // totale invece di lasciare una divergenza latente nel formatter.
        assertThat(UsageWidgetModel.toMinutes(-90_000L)).isEqualTo(0)
        assertThat(UsageWidgetModel.formatDurationMs(-90_000L)).isEqualTo("0m")
    }

    @Test
    fun neverExceedsMaxRowsEvenOnAHugeWidget() {
        // Tetto duro: ogni riga porta una bitmap nella transazione Binder.
        val candidates = List(40) {
            UsageWidgetModel.Row("pkg$it", "App $it", min(10), null, false)
        }
        assertThat(UsageWidgetModel.rowsFittingHeight(4000, candidates))
            .isEqualTo(UsageWidgetModel.MAX_ROWS)
    }

    @Test
    fun neverReturnsMoreRowsThanCandidates() {
        val candidates = listOf(
            UsageWidgetModel.Row(IG, "Instagram", min(10), null, false),
            UsageWidgetModel.Row(YT, "YouTube", min(5), null, false),
        )
        assertThat(UsageWidgetModel.rowsFittingHeight(4000, candidates)).isEqualTo(2)
    }

    // -------- Pill del contatore reel --------

    @Test
    fun reelPill_isVisibleAtZeroWhenTheCounterIsOn() {
        // Cambio di rotta dopo la prova on-device: nascondere la pill a zero
        // rendeva la feature indistinguibile da una rotta il primo giorno.
        // Uno zero, in un widget che misura quanto stai al telefono, è il
        // numero migliore che ci possa stare.
        assertThat(UsageWidgetModel.showsReelPill(0, reelCounterEnabled = true)).isTrue()
        assertThat(UsageWidgetModel.showsReelPill(1, reelCounterEnabled = true)).isTrue()
    }

    @Test
    fun reelPill_isHiddenWhenTheCounterIsOff() {
        // QUESTO è il caso in cui uno "0" perenne sarebbe arredamento: chi ha
        // spento la feature non deve portarsi dietro la pill.
        assertThat(UsageWidgetModel.showsReelPill(0, reelCounterEnabled = false)).isFalse()
        assertThat(UsageWidgetModel.showsReelPill(42, reelCounterEnabled = false)).isFalse()
    }

    @Test
    fun reelPill_isHiddenOnNegativeCounts() {
        // Stato corrotto: meglio niente che un numero senza senso.
        assertThat(UsageWidgetModel.showsReelPill(-5, reelCounterEnabled = true)).isFalse()
    }

    @Test
    fun formatReelCount_isThePlainInteger() {
        // Nessuna abbreviazione: la stessa regola dovrebbe valere anche nella
        // card in-app, e ogni formattazione in più è una parità in più da
        // mantenere fra i due lati.
        assertThat(UsageWidgetModel.formatReelCount(0)).isEqualTo("0")
        assertThat(UsageWidgetModel.formatReelCount(7)).isEqualTo("7")
        assertThat(UsageWidgetModel.formatReelCount(1500)).isEqualTo("1500")
    }

    @Test
    fun formatReelCount_clampsNegativeInput() {
        assertThat(UsageWidgetModel.formatReelCount(-3)).isEqualTo("0")
    }

    @Test
    fun snapshotDefaultsToZeroReelsWithTheCounterOn() {
        // I default dello snapshot descrivono il caso NORMALE (contatore acceso,
        // nessuno scroll ancora): la pill si vede e dice 0.
        val snapshot = UsageWidgetModel.Snapshot(totalMs = min(30), rows = emptyList())
        assertThat(snapshot.reelsToday).isEqualTo(0)
        assertThat(snapshot.reelCounterEnabled).isTrue()
        assertThat(
            UsageWidgetModel.showsReelPill(snapshot.reelsToday, snapshot.reelCounterEnabled),
        ).isTrue()
    }

    @Test
    fun reelCount_doesNotAffectRowFitting() {
        // La pill vive DENTRO l'header, quindi il budget di altezza per le
        // righe non cambia: è tutto il motivo per cui sta lì invece che su una
        // riga propria. Se qualcuno la sposta, questo test non se ne accorge da
        // solo — ma HEADER_DP sì, e lì il commento spiega il vincolo.
        val candidates = List(3) {
            UsageWidgetModel.Row("pkg$it", "App $it", min(10), null, false)
        }
        val height = UsageWidgetModel.ROOT_VPADDING_DP +
            UsageWidgetModel.HEADER_DP +
            3 * UsageWidgetModel.PLAIN_ROW_DP
        assertThat(UsageWidgetModel.rowsFittingHeight(height, candidates)).isEqualTo(3)
    }
}
