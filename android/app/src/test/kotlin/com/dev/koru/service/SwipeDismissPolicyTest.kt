package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Tests for [shouldDismissOnSwipeUp] — il gate del gesto "swipe-up chiude
 * l'overlay di blocco".
 *
 * Le soglie in px sono calcolate qui a densità 3x (dp * 3) per leggere i
 * numeri come li vede un device reale; la funzione è density-agnostica.
 */
class SwipeDismissPolicyTest {

    private val density = 3f
    private val shortPx = SwipeDismissDefaults.SHORT_DP * density        // 72px
    private val longPx = SwipeDismissDefaults.LONG_DP * density          // 144px
    private val flingPx = SwipeDismissDefaults.FLING_DP_PER_SEC * density // 900px/s

    private fun decide(dyPx: Float, velocityPx: Float) = shouldDismissOnSwipeUp(
        dyTotalPx = dyPx,
        velocityYPxPerSec = velocityPx,
        shortPx = shortPx,
        longPx = longPx,
        flingPxPerSec = flingPx,
    )

    @Test
    fun `swipe down is never a dismiss`() {
        assertThat(decide(dyPx = 500f, velocityPx = 4000f)).isFalse()
        // Anche un fling verso il basso velocissimo: la direzione decide prima.
        assertThat(decide(dyPx = 500f, velocityPx = -4000f)).isFalse()
    }

    @Test
    fun `zero movement is never a dismiss`() {
        assertThat(decide(dyPx = 0f, velocityPx = -5000f)).isFalse()
    }

    @Test
    fun `fast flick dismisses at the short threshold`() {
        assertThat(decide(dyPx = -shortPx, velocityPx = -flingPx)).isTrue()
        assertThat(decide(dyPx = -(shortPx + 1f), velocityPx = -2000f)).isTrue()
    }

    @Test
    fun `fast flick shorter than the short threshold does not dismiss`() {
        assertThat(decide(dyPx = -(shortPx - 1f), velocityPx = -3000f)).isFalse()
    }

    @Test
    fun `slow drag needs the long threshold`() {
        // Questo è il caso "tap sporco" su un pulsante: si muove quanto un
        // flick ma piano — non deve chiudere l'overlay.
        assertThat(decide(dyPx = -shortPx, velocityPx = -100f)).isFalse()
        assertThat(decide(dyPx = -(longPx - 1f), velocityPx = -100f)).isFalse()
        assertThat(decide(dyPx = -longPx, velocityPx = -100f)).isTrue()
    }

    @Test
    fun `long threshold is lower than the old flat 80dp`() {
        // Regressione sul valore: la modifica esiste per abbassare lo spazio
        // richiesto, in ENTRAMBI i rami.
        assertThat(SwipeDismissDefaults.LONG_DP).isLessThan(80f)
        assertThat(SwipeDismissDefaults.SHORT_DP).isLessThan(SwipeDismissDefaults.LONG_DP)
    }
}
