package com.dev.koru.service

import com.dev.koru.overlay.BlockReason

/**
 * Decisione PURA della strategia di uscita da un'app bloccata: BACK "morbido"
 * oppure HOME "duro".
 *
 * ## Perche' esiste (il bug che l'ha motivata)
 * Le due strategie sono implementate in
 * [KoruAccessibilityService.performGoHomeForBlock], ma la SCELTA fra le due era
 * sparsa: ogni ramo di blocco passava a mano il proprio `forceHome`, e l'unico
 * posto dove la policy era scritta per intero era un commento — che si e'
 * disallineato dal codice. Il commento diceva "APP_BLOCKED → BACK, tutto il
 * resto → HOME", mentre il cap giornaliero faceva BACK.
 *
 * L'effetto on-device era una cascata: il cap scatta mentre l'utente e' dentro
 * (es. Instagram, tre schermate in profondita'), Koru fa BACK, l'app pop-pa una
 * sola schermata e resta in foreground → nuovo `TYPE_WINDOW_STATE_CHANGED` →
 * il cap e' ancora superato → nuovo BACK. L'utente vedeva l'app risalire il
 * proprio stack "back, back, back" invece di essere chiusa.
 *
 * La regola in una riga: **BACK solo quando l'app non e' ancora davvero
 * aperta**. E' il caso di APP_BLOCKED con apertura diretta dall'icona, dove il
 * BACK riporta l'utente esattamente alla pagina del launcher da cui e' partito
 * (HOME lo riporterebbe alla pagina 1). In tutti gli altri casi l'utente e'
 * DENTRO l'app — il limite e' scattato durante l'uso, la sezione bloccata e' una
 * sub-activity, il TTL del bypass e' scaduto in foreground — e un BACK naviga lo
 * stack interno invece di chiudere.
 *
 * La decisione e' funzione pura del [BlockReason], quindi vive qui ed e'
 * unit-testabile senza Robolectric (stesso ragionamento di [MediaSilencePolicy]
 * e [BlockPolicyEvaluator]). Il side-effect — BACK, HOME intent, fallback —
 * resta in [KoruAccessibilityService].
 */
object BlockExitPolicy {

    /**
     * Se l'uscita per [reason] debba forzare HOME (`true`) invece di tentare
     * prima un BACK (`false`).
     *
     * Il `when` e' deliberatamente esaustivo e senza `else`: un nuovo
     * [BlockReason] non compila finche' non si e' deciso da che parte sta. E'
     * esattamente il tipo di drift silenzioso che ha prodotto il bug del cap.
     */
    fun forceHomeFor(reason: BlockReason): Boolean = when (reason) {
        // Unico caso "morbido": l'utente ha tappato l'icona dal launcher e
        // l'app sta comparendo ORA. BACK annulla l'apertura e lo rimette dove
        // era (sub-pagina del launcher compresa).
        BlockReason.APP_BLOCKED -> false

        // Cap giornaliero: scatta tipicamente mentre l'utente sta gia' usando
        // l'app. BACK risalirebbe lo stack una schermata per volta.
        BlockReason.USAGE_LIMIT -> true

        // Sezione (Reels/Shorts): BACK chiuderebbe solo il viewer lasciando
        // l'utente sulla home dell'app, libero di rientrare subito.
        BlockReason.SECTION_BLOCKED -> true

        // Sito bloccato: la scheda e' gia' stata neutralizzata, il browser va
        // mandato in background per intero.
        BlockReason.WEBSITE_BLOCKED -> true

        // TTL scaduto mentre l'utente era in foreground: "Close $app" e' una
        // richiesta esplicita di buttare via la task.
        BlockReason.BYPASS_EXPIRED -> true
    }
}
