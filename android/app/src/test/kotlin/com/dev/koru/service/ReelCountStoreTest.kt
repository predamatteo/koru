package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests di [ReelCountStore]. Due famiglie:
 *  - il merge PURO (`merge`), dove vivono i casi di rollover e di flush
 *    ritardato che sono impossibili da produrre a comando su un device;
 *  - il round-trip su file (add → flush → read), che verifica codec, buffer
 *    write-behind e visibilità dei conteggi non ancora versati.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class ReelCountStoreTest {

    private val fileName = "koru_reel_counts.json"
    private val IG = "INSTAGRAM_REELS"
    private val YT = "YOUTUBE_SHORTS"

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Before
    fun setUp() = clearFileAndCache()

    @After
    fun tearDown() = clearFileAndCache()

    private fun clearFileAndCache() {
        val ctx = context
        File(ctx.filesDir, fileName).delete()
        File(ctx.filesDir, "$fileName.tmp").delete()
        File(ctx.filesDir, "$fileName.lock").delete()
        ReelCountStore.invalidateCacheForTest()
    }

    private fun state(
        todayStart: Long,
        todayCounts: Map<String, Int> = emptyMap(),
        history: List<ReelCountStore.DayCounts> = emptyList(),
    ) = ReelCountStore.State(ReelCountStore.DayCounts(todayStart, todayCounts), history)

    // ── merge: stesso giorno ───────────────────────────────────────────────

    @Test
    fun merge_sameDay_sumsIntoCurrentCounts() {
        val before = state(DAY_2, mapOf(IG to 10))
        val after = ReelCountStore.merge(before, DAY_2, mapOf(IG to 3, YT to 5), 30)
        assertThat(after.today.dayStartMs).isEqualTo(DAY_2)
        assertThat(after.today.counts).containsExactly(IG, 13, YT, 5)
        assertThat(after.history).isEmpty()
    }

    @Test
    fun merge_emptyDelta_isNoOp() {
        val before = state(DAY_2, mapOf(IG to 10))
        assertThat(ReelCountStore.merge(before, DAY_2, emptyMap(), 30)).isEqualTo(before)
    }

    @Test
    fun merge_ontoEmptyState_startsTheDay() {
        val after = ReelCountStore.merge(ReelCountStore.State.EMPTY, DAY_2, mapOf(IG to 4), 30)
        assertThat(after.today.dayStartMs).isEqualTo(DAY_2)
        assertThat(after.today.counts).containsExactly(IG, 4)
        // Nessuna riga di storia per il "giorno zero" dello stato vuoto.
        assertThat(after.history).isEmpty()
    }

    // ── merge: rollover ────────────────────────────────────────────────────

    @Test
    fun merge_newerDay_archivesTheCurrentDay() {
        val before = state(DAY_1, mapOf(IG to 40))
        val after = ReelCountStore.merge(before, DAY_2, mapOf(IG to 1), 30)
        assertThat(after.today.dayStartMs).isEqualTo(DAY_2)
        assertThat(after.today.counts).containsExactly(IG, 1)
        assertThat(after.history).hasSize(1)
        assertThat(after.history[0].dayStartMs).isEqualTo(DAY_1)
        assertThat(after.history[0].counts).containsExactly(IG, 40)
    }

    @Test
    fun merge_newerDay_doesNotArchiveAnEmptyDay() {
        val before = state(DAY_1, emptyMap())
        val after = ReelCountStore.merge(before, DAY_2, mapOf(IG to 1), 30)
        assertThat(after.history).isEmpty()
    }

    @Test
    fun merge_trimsHistoryToTheCap() {
        var current = ReelCountStore.State.EMPTY
        // 5 giorni consecutivi con un cap di 3: restano i 3 più recenti.
        for (i in 0 until 5) {
            current = ReelCountStore.merge(current, DAY_1 + i * DAY_MS, mapOf(IG to i + 1), 3)
        }
        assertThat(current.today.dayStartMs).isEqualTo(DAY_1 + 4 * DAY_MS)
        assertThat(current.history).hasSize(3)
        assertThat(current.history.map { it.dayStartMs })
            .containsExactly(DAY_1 + 3 * DAY_MS, DAY_1 + 2 * DAY_MS, DAY_1 + DAY_MS)
            .inOrder()
    }

    // ── merge: flush in ritardo attraverso la mezzanotte ──────────────────

    @Test
    fun merge_olderDay_landsInHistoryNotOnToday() {
        // Il caso reale: si scrolla fino a mezzanotte passata, un flush apre il
        // giorno nuovo, e solo dopo arriva il buffer della sera prima.
        val before = state(DAY_2, mapOf(IG to 2), listOf(ReelCountStore.DayCounts(DAY_1, mapOf(IG to 40))))
        val after = ReelCountStore.merge(before, DAY_1, mapOf(IG to 7), 30)
        assertThat(after.today.counts).containsExactly(IG, 2)
        assertThat(after.history).hasSize(1)
        assertThat(after.history[0].counts).containsExactly(IG, 47)
    }

    @Test
    fun merge_olderDayWithoutAnExistingRow_isInsertedSorted() {
        val before = state(DAY_3, mapOf(IG to 1), listOf(ReelCountStore.DayCounts(DAY_1, mapOf(IG to 5))))
        val after = ReelCountStore.merge(before, DAY_2, mapOf(YT to 9), 30)
        assertThat(after.history.map { it.dayStartMs }).containsExactly(DAY_2, DAY_1).inOrder()
        assertThat(after.history[0].counts).containsExactly(YT, 9)
    }

    @Test
    fun merge_ignoresNonPositiveDayStart() {
        val before = state(DAY_2, mapOf(IG to 1))
        assertThat(ReelCountStore.merge(before, 0L, mapOf(IG to 5), 30)).isEqualTo(before)
    }

    // ── Round-trip su file ────────────────────────────────────────────────

    @Test
    fun add_isVisibleImmediately_evenBeforeTheFlush() {
        // Sotto la soglia di flush: il conteggio vive solo in memoria, ma la
        // UI deve comunque vederlo (altrimenti il widget mostrerebbe l'ultimo
        // flush invece dell'ultimo reel).
        ReelCountStore.add(context, IG, 1)
        assertThat(ReelCountStore.todayCounts(context)).containsExactly(IG, 1)
        assertThat(File(context.filesDir, fileName).exists()).isFalse()
    }

    @Test
    fun add_reachingTheThreshold_writesToDisk() {
        repeat(ReelCountStore.FLUSH_EVERY_COUNTS) { ReelCountStore.add(context, IG, 1) }
        assertThat(File(context.filesDir, fileName).exists()).isTrue()
        assertThat(ReelCountStore.todayTotal(context))
            .isEqualTo(ReelCountStore.FLUSH_EVERY_COUNTS)
    }

    @Test
    fun counts_survivePersistenceRoundTrip() {
        ReelCountStore.add(context, IG, 3)
        ReelCountStore.add(context, YT, 2)
        assertThat(ReelCountStore.flush(context)).isTrue()
        // Simula un altro lettore (widget worker): cache di processo svuotata,
        // il dato deve arrivare dal file.
        ReelCountStore.invalidateCacheForTest()
        assertThat(ReelCountStore.todayCounts(context)).containsExactly(IG, 3, YT, 2)
    }

    @Test
    fun add_mixesSourcesWithoutLosingEither() {
        ReelCountStore.add(context, IG, 4)
        ReelCountStore.add(context, YT, 6)
        ReelCountStore.add(context, IG, 1)
        assertThat(ReelCountStore.todayCounts(context)).containsExactly(IG, 5, YT, 6)
        assertThat(ReelCountStore.todayTotal(context)).isEqualTo(11)
    }

    @Test
    fun add_ignoresNonPositiveDeltas() {
        ReelCountStore.add(context, IG, 0)
        ReelCountStore.add(context, IG, -3)
        assertThat(ReelCountStore.todayCounts(context)).isEmpty()
    }

    @Test
    fun flush_withNothingPending_succeedsAndWritesNothing() {
        assertThat(ReelCountStore.flush(context)).isTrue()
        assertThat(File(context.filesDir, fileName).exists()).isFalse()
    }

    @Test
    fun clear_dropsPendingAndPersisted() {
        ReelCountStore.add(context, IG, 3)
        ReelCountStore.flush(context)
        ReelCountStore.add(context, IG, 1) // resta pending
        assertThat(ReelCountStore.clear(context)).isTrue()
        assertThat(ReelCountStore.todayCounts(context)).isEmpty()
    }

    // ── recentDays ────────────────────────────────────────────────────────

    @Test
    fun recentDays_startsFromTodayAndFillsGapsWithZero() {
        ReelCountStore.add(context, IG, 7)
        val days = ReelCountStore.recentDays(context, 7)
        assertThat(days).hasSize(7)
        assertThat(days[0].dayStartMs)
            .isEqualTo(ReelCountStore.localDayStart(System.currentTimeMillis()))
        assertThat(days[0].total).isEqualTo(7)
        // I giorni senza scrolling ci sono comunque, a zero: un grafico non
        // deve indovinare i buchi.
        assertThat(days.drop(1).map { it.total }).containsExactly(0, 0, 0, 0, 0, 0)
    }

    @Test
    fun recentDays_isOrderedNewestFirstWithoutDuplicates() {
        val stamps = ReelCountStore.recentDays(context, 5).map { it.dayStartMs }
        assertThat(stamps).hasSize(5)
        assertThat(stamps.toSet()).hasSize(5) // nessun giorno ripetuto
        for (i in 1 until stamps.size) {
            assertThat(stamps[i]).isLessThan(stamps[i - 1])
        }
    }

    @Test
    fun recentDays_withNonPositiveWindow_isEmpty() {
        assertThat(ReelCountStore.recentDays(context, 0)).isEmpty()
    }

    // ── Confini di giornata ───────────────────────────────────────────────

    @Test
    fun localDayStart_isStableWithinTheSameDay() {
        // Si parte da una mezzanotte VERA e non da una costante arbitraria: le
        // costanti del merge sono solo timestamp ordinabili, mentre qui stiamo
        // testando proprio il confine di giornata, e un valore che cade a metà
        // pomeriggio renderebbe "+22h" un giorno diverso.
        val midnight = ReelCountStore.localDayStart(System.currentTimeMillis())
        assertThat(ReelCountStore.localDayStart(midnight)).isEqualTo(midnight)
        assertThat(ReelCountStore.localDayStart(midnight + 9 * HOUR_MS)).isEqualTo(midnight)
        // +22h e non +23h: su un giorno di transizione DST la giornata locale
        // può durare 23 ore, e il test non deve dipendere dal periodo dell'anno.
        assertThat(ReelCountStore.localDayStart(midnight + 22 * HOUR_MS)).isEqualTo(midnight)
    }

    @Test
    fun previousLocalDayStart_goesBackExactlyOneDay() {
        val today = ReelCountStore.localDayStart(System.currentTimeMillis())
        val yesterday = ReelCountStore.previousLocalDayStart(today)
        assertThat(yesterday).isLessThan(today)
        assertThat(ReelCountStore.localDayStart(yesterday)).isEqualTo(yesterday)
    }

    companion object {
        private const val HOUR_MS = 60L * 60 * 1000
        private const val DAY_MS = 24 * HOUR_MS

        // Mezzanotti fittizie e distinte: il merge non interpreta i timestamp,
        // li ordina soltanto, quindi bastano valori crescenti a distanza di un
        // giorno.
        private const val DAY_1 = 1_755_000_000_000L
        private const val DAY_2 = DAY_1 + DAY_MS
        private const val DAY_3 = DAY_1 + 2 * DAY_MS
    }
}
