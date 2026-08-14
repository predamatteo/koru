package com.dev.koru.content

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [ReelSwipeCounter] (nessun Android, nessun Robolectric).
 *
 * L'avversario qui non è un utente malintenzionato ma il **rumore della view**:
 * un pager emette molti più eventi di quanti swipe faccia l'utente, e ogni
 * scorciatoia sbagliata produce un numero plausibile ma falso. I test sono
 * scritti attorno ai modi realistici in cui il conteggio si gonfia (raffica di
 * eventi per un solo swipe, drag annullato, reset dell'adapter) o si azzera
 * (cambio finestra, indici non riportati).
 */
class ReelSwipeCounterTest {

    private val IG = "INSTAGRAM_REELS"
    private val YT = "YOUTUBE_SHORTS"
    private val WINDOW = 42

    private lateinit var counter: ReelSwipeCounter

    private fun newCounter(): ReelSwipeCounter = ReelSwipeCounter().also { counter = it }

    /// Scroll con indici popolati (il caso previsto: RecyclerView/ViewPager2).
    private fun scroll(
        index: Int,
        atMs: Long,
        section: String = IG,
        windowId: Int = WINDOW,
    ) = counter.onScroll(
        sectionWireId = section,
        windowId = windowId,
        fromIndex = index,
        toIndex = index,
        uptimeMs = atMs,
    )

    /// Scroll da una view che NON riporta gli indici.
    private fun scrollNoIndex(
        atMs: Long,
        section: String = IG,
        windowId: Int = WINDOW,
    ) = counter.onScroll(
        sectionWireId = section,
        windowId = windowId,
        fromIndex = -1,
        toIndex = -1,
        uptimeMs = atMs,
    )

    // ── Baseline: il primo evento non conta ────────────────────────────────

    @Test
    fun firstScrollOfASession_establishesBaselineWithoutCounting() {
        newCounter()
        assertThat(scroll(index = 0, atMs = 1_000).counted).isEqualTo(0)
    }

    @Test
    fun indexAdvance_afterBaseline_countsOne() {
        newCounter()
        scroll(index = 0, atMs = 1_000)
        val result = scroll(index = 1, atMs = 2_000)
        assertThat(result.counted).isEqualTo(1)
        assertThat(result.viaIndex).isTrue()
    }

    // ── Il caso che rende inutile contare gli eventi ───────────────────────

    @Test
    fun burstOfEventsOnTheSameIndex_countsOnlyTheTransition() {
        // Uno swipe reale: il framework consegna più scroll mentre il dito
        // trascina (indice ancora N), poi l'assestamento su N+1, poi ancora
        // eventi di rifinitura. È UN reel, non cinque.
        newCounter()
        scroll(index = 4, atMs = 1_000)
        scroll(index = 4, atMs = 1_100)
        scroll(index = 4, atMs = 1_200)
        val settle = scroll(index = 5, atMs = 1_400)
        val after1 = scroll(index = 5, atMs = 1_600)
        val after2 = scroll(index = 5, atMs = 1_800)

        assertThat(settle.counted).isEqualTo(1)
        assertThat(after1.counted).isEqualTo(0)
        assertThat(after2.counted).isEqualTo(0)
    }

    @Test
    fun dragStartedAndAbandoned_doesNotCount() {
        // Dito giù, un po' di trascinamento, e ritorno sullo stesso reel:
        // `fromIndex` non è mai cambiato → nessun reel guardato.
        newCounter()
        scroll(index = 7, atMs = 1_000)
        scroll(index = 7, atMs = 1_150)
        scroll(index = 7, atMs = 1_400)
        assertThat(scroll(index = 7, atMs = 1_700).counted).isEqualTo(0)
    }

    // ── Direzione: indietro conta come avanti ──────────────────────────────

    @Test
    fun swipingBackwards_countsToo() {
        newCounter()
        scroll(index = 9, atMs = 1_000)
        assertThat(scroll(index = 8, atMs = 2_000).counted).isEqualTo(1)
    }

    // ── Salti: fling veloce vs reset dell'adapter ──────────────────────────

    @Test
    fun fastFlingSkippingTwoReels_countsTheDelta() {
        newCounter()
        scroll(index = 0, atMs = 1_000)
        assertThat(scroll(index = 2, atMs = 2_000).counted).isEqualTo(2)
    }

    @Test
    fun hugeIndexJump_isCappedInsteadOfCredited() {
        // L'adapter si ricarica e l'indice salta a +40: non sono 40 reel
        // guardati in un evento, è la lista che è cambiata sotto.
        newCounter()
        scroll(index = 3, atMs = 1_000)
        val jump = scroll(index = 43, atMs = 2_000)
        assertThat(jump.counted).isEqualTo(ReelSwipeCounter.MAX_JUMP_COUNT)
    }

    @Test
    fun adapterResetToZero_isCappedToo() {
        newCounter()
        scroll(index = 30, atMs = 1_000)
        assertThat(scroll(index = 0, atMs = 2_000).counted)
            .isEqualTo(ReelSwipeCounter.MAX_JUMP_COUNT)
    }

    // ── Rate cap ───────────────────────────────────────────────────────────

    @Test
    fun countsCloserThanTheRateCap_areDropped() {
        newCounter()
        scroll(index = 0, atMs = 1_000)
        assertThat(scroll(index = 1, atMs = 1_200).counted).isEqualTo(1)
        // 50ms dopo: fisicamente impossibile come swipe.
        assertThat(scroll(index = 2, atMs = 1_250).counted).isEqualTo(0)
    }

    @Test
    fun droppedByRateCap_doesNotCorruptTheBaseline() {
        // Un evento scartato dal rate cap non deve far perdere il filo: il
        // conteggio successivo dev'essere 1 (dal 2 al 3), non 2 (dal 1 al 3).
        newCounter()
        scroll(index = 0, atMs = 1_000)
        scroll(index = 1, atMs = 1_200)
        scroll(index = 2, atMs = 1_250) // scartato: troppo ravvicinato
        assertThat(scroll(index = 3, atMs = 2_000).counted).isEqualTo(2)
    }

    // ── Cambio di contesto ─────────────────────────────────────────────────

    @Test
    fun windowChange_resetsBaselineWithoutCounting() {
        newCounter()
        scroll(index = 5, atMs = 1_000)
        // Altra finestra: l'indice 0 non è "5 reel indietro", è un'altra lista.
        assertThat(scroll(index = 0, atMs = 2_000, windowId = 99).counted).isEqualTo(0)
        assertThat(scroll(index = 1, atMs = 3_000, windowId = 99).counted).isEqualTo(1)
    }

    @Test
    fun sectionChange_resetsBaselineWithoutCounting() {
        // Da Reels a Shorts: gli indici delle due liste non sono confrontabili.
        newCounter()
        scroll(index = 12, atMs = 1_000, section = IG)
        assertThat(scroll(index = 0, atMs = 2_000, section = YT).counted).isEqualTo(0)
    }

    @Test
    fun windowChangeWithinTheRateCapWindow_stillResetsTheBaseline() {
        // Regressione: con il rate cap valutato PRIMA del cambio contesto,
        // questo passaggio di finestra veniva scartato senza aggiornare la
        // baseline, e lo scroll successivo veniva confrontato con l'indice
        // della lista precedente → un conteggio inventato.
        newCounter()
        scroll(index = 20, atMs = 1_000)
        scroll(index = 21, atMs = 1_200) // conta 1, fissa lastCount a 1_200
        scroll(index = 0, atMs = 1_250, windowId = 77) // entro il rate cap
        assertThat(scroll(index = 0, atMs = 3_000, windowId = 77).counted).isEqualTo(0)
    }

    @Test
    fun reset_dropsTheBaseline() {
        newCounter()
        scroll(index = 5, atMs = 1_000)
        counter.reset()
        // Dopo il reset il primo evento è di nuovo solo una baseline.
        assertThat(scroll(index = 6, atMs = 2_000).counted).isEqualTo(0)
        assertThat(scroll(index = 7, atMs = 3_000).counted).isEqualTo(1)
    }

    // ── Fallback senza indici ──────────────────────────────────────────────

    @Test
    fun withoutIndices_countsOnDebounceAndFlagsTheFallback() {
        newCounter()
        scrollNoIndex(atMs = 1_000) // baseline
        val counted = scrollNoIndex(atMs = 1_000 + ReelSwipeCounter.FALLBACK_DEBOUNCE_MS)
        assertThat(counted.counted).isEqualTo(1)
        assertThat(counted.viaIndex).isFalse()
    }

    @Test
    fun withoutIndices_eventsInsideTheDebounceAreDropped() {
        newCounter()
        scrollNoIndex(atMs = 1_000)
        assertThat(scrollNoIndex(atMs = 1_300).counted).isEqualTo(0)
        assertThat(scrollNoIndex(atMs = 1_400).counted).isEqualTo(0)
    }

    @Test
    fun indicesAppearingLater_switchBackToTheIndexPath() {
        // Prima evento senza indici, poi la view comincia a riportarli.
        newCounter()
        scrollNoIndex(atMs = 1_000)
        val bridge = scrollNoIndex(atMs = 2_000)
        assertThat(bridge.viaIndex).isFalse()
        scroll(index = 4, atMs = 3_000) // riallinea la baseline sull'indice
        val viaIndex = scroll(index = 5, atMs = 4_000)
        assertThat(viaIndex.counted).isEqualTo(1)
        assertThat(viaIndex.viaIndex).isTrue()
    }

    @Test
    fun onlyToIndexAvailable_isUsedAsFallbackIndex() {
        newCounter()
        counter.onScroll(IG, WINDOW, fromIndex = -1, toIndex = 3, uptimeMs = 1_000)
        val result = counter.onScroll(IG, WINDOW, fromIndex = -1, toIndex = 4, uptimeMs = 2_000)
        assertThat(result.counted).isEqualTo(1)
        assertThat(result.viaIndex).isTrue()
    }

    // ── Proprietà d'insieme ────────────────────────────────────────────────

    @Test
    fun aRealisticSession_countsOneReelPerSwipe() {
        // 10 swipe, ciascuno con 3 eventi di trascinamento + 1 assestamento.
        newCounter()
        var t = 1_000L
        scroll(index = 0, atMs = t)
        var total = 0
        for (i in 1..10) {
            repeat(3) {
                t += 100
                total += scroll(index = i - 1, atMs = t).counted
            }
            t += 200
            total += scroll(index = i, atMs = t).counted
        }
        assertThat(total).isEqualTo(10)
    }
}
