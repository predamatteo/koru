package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [GhostEventFilter.isGhostEvent]. Avversario: l'utente che cerca
 * buchi di enforcement. La proprieta' di sicurezza chiave e' FAIL-SECURE: in
 * dubbio (foreground non determinabile, o foreground = launcher/systemui che
 * puo' essere stale) NON si tratta l'evento come ghost → si procede a valutare
 * il blocco. Solo quando il foreground reale e' un'ALTRA app non-skip l'evento
 * e' un ghost di uscita da ignorare.
 */
class GhostEventFilterTest {

    private val IG = "com.instagram.android"
    private val WA = "com.whatsapp"
    private val LAUNCHER = "com.android.launcher3"

    @Test
    fun realForegroundIsAnotherNonSkipApp_isGhost() {
        // Evento per IG ma il foreground reale e' WA (non-skip) ⇒ ghost di uscita.
        assertThat(
            GhostEventFilter.isGhostEvent(
                eventPackage = IG,
                realForegroundPackage = WA,
                isRealForegroundSkippable = false,
            ),
        ).isTrue()
    }

    @Test
    fun realForegroundMatchesEventPackage_notGhost() {
        // Il foreground reale E' il pkg dell'evento ⇒ apertura legittima.
        assertThat(
            GhostEventFilter.isGhostEvent(
                eventPackage = IG,
                realForegroundPackage = IG,
                isRealForegroundSkippable = false,
            ),
        ).isFalse()
    }

    @Test
    fun realForegroundNull_notGhost_failSecure() {
        // UsageStats non risponde (null) ⇒ NON ghost: in dubbio si procede a
        // bloccare (piu' sicuro che lasciar passare).
        assertThat(
            GhostEventFilter.isGhostEvent(
                eventPackage = IG,
                realForegroundPackage = null,
                isRealForegroundSkippable = false,
            ),
        ).isFalse()
    }

    @Test
    fun realForegroundIsSkippable_notGhost() {
        // Foreground = launcher/systemui (skippable): UsageStats puo' laggare
        // subito dopo un HOME, quindi NON ghost (procediamo). Il pkg dell'evento
        // e' diverso dal launcher ma lo skip-flag vince.
        assertThat(
            GhostEventFilter.isGhostEvent(
                eventPackage = IG,
                realForegroundPackage = LAUNCHER,
                isRealForegroundSkippable = true,
            ),
        ).isFalse()
    }

    @Test
    fun nullForegroundIsNeverSkippable_stillNotGhost() {
        // Difensivo: anche se il chiamante passasse isSkippable=true con fg=null
        // (incoerente), il null domina e il risultato resta NON ghost.
        assertThat(
            GhostEventFilter.isGhostEvent(
                eventPackage = IG,
                realForegroundPackage = null,
                isRealForegroundSkippable = true,
            ),
        ).isFalse()
    }
}
