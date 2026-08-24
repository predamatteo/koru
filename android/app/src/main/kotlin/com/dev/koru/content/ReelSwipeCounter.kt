package com.dev.koru.content

/**
 * Decide quanti reel contare a partire da un `TYPE_VIEW_SCROLLED` già
 * riconosciuto come proveniente da un pager di Reels/Shorts.
 *
 * ## Perché serve una macchina a stati e non un contatore di eventi
 * Android non espone "l'utente ha swipato un reel": lo si inferisce dallo
 * scroll. Ma un singolo fling produce 3-8 `TYPE_VIEW_SCROLLED` (con
 * `notificationTimeout=100` li riceviamo quasi tutti), quindi contare gli
 * eventi darebbe numeri 4-8 volte più grandi del vero. Il segnale giusto è il
 * **cambio di indice dell'item**: `RecyclerView.onInitializeAccessibilityEvent`
 * popola `fromIndex`/`toIndex` con la posizione del primo/ultimo item visibile,
 * e su un pager a pagina piena quella posizione avanza **una volta sola** per
 * swipe. Durante il drag `fromIndex` resta N (l'item uscente è ancora il primo
 * visibile) e diventa N+1 all'assestamento: un conteggio, nel momento giusto.
 *
 * ## Cosa conta come "1 reel"
 * Un cambio di indice, in **entrambe le direzioni**: tornare indietro di un
 * reel è comunque un reel guardato. Conseguenza da conoscere: il PRIMO reel di
 * ogni sessione non viene contato, perché non nasce da una transizione. È
 * coerente con la semantica "reel swipati" (su quello ci sei atterrato, non ci
 * hai swipato) ed è la direzione di errore giusta: preferiamo sottostimare di
 * uno che inventare conteggi su ogni sfarfallio di finestra.
 *
 * ## Fallback quando gli indici non ci sono
 * Alcune view custom non popolano `fromIndex`/`toIndex` (restano a -1). In quel
 * caso si degrada a un debounce temporale: un conteggio ogni
 * [FALLBACK_DEBOUNCE_MS], che è più lento di quanto una mano possa swipare ma
 * abbastanza da non perdere lo scroll normale. È una rete di sicurezza, non il
 * percorso previsto: il chiamante logga quale dei due path ha prodotto il
 * conteggio ([Result.viaIndex]) proprio per poter verificare on-device che il
 * ramo indici funzioni davvero — se il fallback domina, i numeri vanno presi
 * con le pinze.
 *
 * Classe (non object) e stato interamente locale: nessuna dipendenza Android,
 * quindi testabile in JVM senza Robolectric — stesso pattern di
 * [com.dev.koru.service.WatchedPackageCalculator] e
 * [com.dev.koru.service.BlockPolicyEvaluator]. Il chiamante ne tiene UNA
 * istanza (il servizio di accessibilità è single-thread sui suoi eventi).
 */
class ReelSwipeCounter {

    /**
     * @param counted quanti reel accreditare (0 = niente da contare).
     * @param viaIndex `true` se il conteggio viene dal cambio di indice,
     *   `false` se dal debounce di fallback. Serve solo alla diagnostica.
     */
    data class Result(val counted: Int, val viaIndex: Boolean) {
        val isCounted: Boolean get() = counted > 0
    }

    private var lastSectionWireId: String? = null
    private var lastWindowId: Int = INVALID_WINDOW
    private var lastIndex: Int = NO_INDEX

    /// 0 e non `Long.MIN_VALUE`: le differenze `uptimeMs - lastCountUptimeMs`
    /// andrebbero in overflow con un sentinella al minimo del range, e un
    /// overflow qui si presenta come "ogni evento è troppo ravvicinato" —
    /// cioè un contatore permanentemente fermo a zero. Con 0 il valore non è
    /// comunque mai letto prima di essere inizializzato: il primo evento dopo
    /// la costruzione (o dopo [reset]) passa sempre dal ramo cambio-contesto,
    /// che lo imposta.
    private var lastCountUptimeMs: Long = 0L

    /**
     * @param sectionWireId sezione riconosciuta dal view-id del `source`
     *   (`INSTAGRAM_REELS` / `YOUTUBE_SHORTS`).
     * @param windowId `AccessibilityEvent.getWindowId()`: cambia quando l'utente
     *   passa a un'altra finestra, e allora l'indice precedente non è più
     *   confrontabile.
     * @param fromIndex / @param toIndex indici dell'item primo/ultimo visibile,
     *   `-1` se la view non li popola.
     * @param uptimeMs orologio MONOTONO (`SystemClock.uptimeMillis`), non
     *   l'orologio di parete: un cambio di ora non deve produrre conteggi.
     */
    fun onScroll(
        sectionWireId: String,
        windowId: Int,
        fromIndex: Int,
        toIndex: Int,
        uptimeMs: Long,
    ): Result {
        val index = resolveIndex(fromIndex, toIndex)

        // Il cambio di contesto va gestito PRIMA di qualunque altro filtro: se
        // il rate cap uscisse per primo, un passaggio di finestra avvenuto
        // entro [MIN_COUNT_INTERVAL_MS] dall'ultimo conteggio lascerebbe la
        // baseline vecchia, e il primo scroll nella finestra nuova verrebbe
        // confrontato con l'indice di un'altra lista.
        if (sectionWireId != lastSectionWireId || windowId != lastWindowId) {
            // Nuova sessione (o rientro dopo essere usciti): fissiamo la
            // baseline senza contare. Vedi "Cosa conta come 1 reel".
            lastSectionWireId = sectionWireId
            lastWindowId = windowId
            lastIndex = index
            // Il debounce del fallback riparte da qui, così il primo scroll
            // dopo l'ingresso non viene accreditato solo perché era passato
            // molto tempo dall'ultima sessione.
            lastCountUptimeMs = uptimeMs
            return NOTHING
        }

        // Rate cap assoluto: nessuna mano swipa più veloce di così, quindi
        // qualunque raffica più fitta è rumore della view (assestamenti,
        // bounce di fine lista, animazioni). Vale per ENTRAMBI i path.
        if (uptimeMs - lastCountUptimeMs < MIN_COUNT_INTERVAL_MS) return NOTHING

        if (index == NO_INDEX || lastIndex == NO_INDEX) {
            // Indici non disponibili (né ora né prima): debounce temporale.
            if (uptimeMs - lastCountUptimeMs < FALLBACK_DEBOUNCE_MS) return NOTHING
            lastIndex = index
            lastCountUptimeMs = uptimeMs
            return Result(1, viaIndex = false)
        }

        if (index == lastIndex) return NOTHING

        val delta = Math.abs(index - lastIndex)
        lastIndex = index
        lastCountUptimeMs = uptimeMs
        // Il cap non è pignoleria: quando l'adapter si ricarica (nuova pagina
        // di reel caricata, ritorno da un profilo aperto dal reel) l'indice può
        // saltare a 0 o a +40 senza che l'utente abbia swipato nulla. Un fling
        // molto veloce salta legittimamente 2-3 item, oltre è quasi sempre un
        // reset della lista: contiamo il tetto invece del salto.
        return Result(delta.coerceAtMost(MAX_JUMP_COUNT), viaIndex = true)
    }

    /// Azzera lo stato: il prossimo scroll ricomincia da una baseline pulita.
    /// Chiamata quando la sessione non è più credibile (schermo spento, utente
    /// uscito dall'app), così un rientro non viene confrontato con un indice
    /// vecchio di ore.
    fun reset() {
        lastSectionWireId = null
        lastWindowId = INVALID_WINDOW
        lastIndex = NO_INDEX
        lastCountUptimeMs = 0L
    }

    /**
     * L'indice da confrontare fra un evento e il successivo.
     *
     * Usiamo `fromIndex` (primo item visibile) e non `toIndex`: su un pager a
     * pagina piena i due coincidono da fermi, ma durante il drag `toIndex` è
     * già l'item entrante mentre `fromIndex` è ancora quello uscente. Contando
     * su `fromIndex` il conteggio scatta quando lo swipe è ASSESTATO, non
     * appena il dito si muove — quindi un drag iniziato e annullato non lascia
     * un reel fantasma. `toIndex` resta come ripiego quando `fromIndex` manca.
     */
    private fun resolveIndex(fromIndex: Int, toIndex: Int): Int = when {
        fromIndex >= 0 -> fromIndex
        toIndex >= 0 -> toIndex
        else -> NO_INDEX
    }

    companion object {
        /// Nessun indice riportato dalla view.
        const val NO_INDEX = -1

        private const val INVALID_WINDOW = Int.MIN_VALUE

        /// Intervallo minimo fra due conteggi. ~7 reel/secondo è già oltre il
        /// limite fisico di uno swipe umano.
        internal const val MIN_COUNT_INTERVAL_MS = 150L

        /// Debounce del ramo senza indici. Volutamente più largo di
        /// [MIN_COUNT_INTERVAL_MS]: lì contiamo su un segnale certo (l'indice è
        /// cambiato), qui stiamo indovinando e un sovra-conteggio si vede.
        internal const val FALLBACK_DEBOUNCE_MS = 500L

        /// Tetto ai reel accreditati da un singolo salto d'indice.
        internal const val MAX_JUMP_COUNT = 3

        private val NOTHING = Result(0, viaIndex = false)
    }
}
