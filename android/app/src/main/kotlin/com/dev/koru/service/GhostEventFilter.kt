package com.dev.koru.service

/**
 * Euristica PURA del "ghost event" del path accessibility.
 *
 * ## Perche' esiste (ARCH-05 / sicurezza)
 * TYPE_WINDOW_STATE_CHANGED / TYPE_WINDOWS_CHANGED possono essere emessi anche
 * per un'app che sta PERDENDO il foreground durante una transizione. Agire su
 * uno di questi eventi (mostrare overlay + GLOBAL_ACTION_BACK) mentre un'altra
 * app sta gia' diventando foreground reale produce il loop vizioso descritto in
 * [KoruAccessibilityService.checkAppBlocking] (overlay che resta sopra l'app
 * sbagliata, doppio blocco).
 *
 * La DECISIONE — "questo evento e' un ghost di uscita, da ignorare?" — e' una
 * funzione pura dei suoi input. La estraggo qui per renderla unit-testabile
 * (l'avversario e' l'utente che cerca buchi di enforcement: la proprieta'
 * fail-secure "in dubbio NON skippare" e' di sicurezza e va testata). Il
 * side-effect — leggere il foreground reale via `ForegroundDetector` (UsageStats)
 * — resta nel service, che passa il risultato qui.
 */
object GhostEventFilter {

    /**
     * `true` se l'evento per [eventPackage] va trattato come ghost di uscita e
     * quindi IGNORATO. Semantica IDENTICA al guard inline precedente:
     *
     *   ghost ⇔ foreground reale noto && diverso da eventPackage && non-skip
     *
     * @param eventPackage il package dell'AccessibilityEvent in esame.
     * @param realForegroundPackage il foreground reale secondo UsageStats, o
     *   `null` se non determinabile (permesso revocato, boot prematuro, lag).
     * @param isRealForegroundSkippable `true` se [realForegroundPackage] e' nel
     *   set degli skip (launcher / systemui): in quel caso NON e' un ghost
     *   (procediamo) perche' UsageStats puo' laggare subito dopo un HOME.
     *
     * Fail-secure: foreground `null` ⇒ NON ghost (in dubbio si procede a
     * valutare il blocco, che e' piu' sicuro che lasciar passare l'app).
     */
    fun isGhostEvent(
        eventPackage: String,
        realForegroundPackage: String?,
        isRealForegroundSkippable: Boolean,
    ): Boolean =
        realForegroundPackage != null &&
            realForegroundPackage != eventPackage &&
            !isRealForegroundSkippable
}
