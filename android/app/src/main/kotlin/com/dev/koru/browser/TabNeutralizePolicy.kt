package com.dev.koru.browser

/**
 * Decisione PURA di come "liberare" la scheda del browser rimasta su un sito
 * bloccato.
 *
 * ## Il bug che l'ha motivata
 * Fino ad ora bloccare un sito voleva dire overlay + HOME, e basta: la scheda
 * restava viva, sul dominio bloccato. Ma il browser, alla riapertura,
 * ripristina esattamente quella scheda — quindi nuovo evento finestra, nuovo
 * match, nuovo overlay, nuovo HOME. Il browser diventa **inapribile**: non c'e'
 * nessun istante in cui l'utente riesce a toccare la UI delle schede per
 * chiudere quella incriminata.
 *
 * L'unica via d'uscita osservata dall'utente era: disattivare il profilo,
 * aprire il browser, chiudere la scheda a mano, riattivare il profilo. Cioe'
 * l'enforcement finiva per punire l'uso del browser invece che del sito.
 *
 * ## Perche' "svuotare" e non "chiudere"
 * Chiudere davvero la scheda richiederebbe di pilotare il selettore schede
 * (`tab_switcher_button` → card → `action_button`): view-id interni di Chrome,
 * che cambiano ad ogni redesign e non esistono negli altri ~30 browser di
 * [BrowserConfigLoader]. Portare la scheda su una pagina neutra usa invece
 * l'UNICO nodo che Koru sa gia' trovare su tutti — la barra degli indirizzi
 * ([UrlBarNodeFinder]) — e ottiene lo stesso risultato pratico: alla
 * riapertura il browser non e' piu' su un dominio bloccato.
 *
 * ## Perche' questo file e' puro
 * La DECISIONE ("con questo nodo si puo' scrivere? serve prima il focus? ci
 * arrendiamo?") e' una funzione dei suoi input, quindi vive qui ed e'
 * unit-testabile senza device — stesso pattern di [com.dev.koru.service.MediaSilencePolicy]
 * e [com.dev.koru.service.WatchedPackageCalculator]. Il side-effect — parlare
 * con [android.view.accessibility.AccessibilityNodeInfo] — sta in
 * [TabNeutralizer].
 *
 * ## Fail-safe
 * Ogni ramo che non sa cosa fare ritorna [Step.UNSUPPORTED], e il chiamante
 * degrada ESATTAMENTE al comportamento precedente (overlay + HOME). Nessun
 * esito di questa policy puo' rendere l'enforcement piu' permissivo: la
 * navigazione verso [NEUTRAL_URL] avviene mentre l'overlay e' gia' montato e
 * il HOME parte comunque subito dopo.
 */
object TabNeutralizePolicy {

    /**
     * Dove viene portata la scheda. `about:blank` e' l'unico URL "vuoto"
     * accettato da tutti i motori (Chromium, Gecko, WebView) — `chrome://newtab`
     * funzionerebbe solo sui Chromium e verrebbe rifiutato altrove.
     */
    const val NEUTRAL_URL = "about:blank"

    /**
     * API minima per poter CONFERMARE la navigazione.
     *
     * Scrivere nella barra degli indirizzi si fa con `ACTION_SET_TEXT` (API 21),
     * ma premere "vai" richiede `ACTION_IME_ENTER`, che esiste solo da API 30
     * (Android 11). Sotto quella soglia non c'e' modo pubblico per un
     * AccessibilityService di inviare l'azione IME: scriveremmo l'URL senza
     * poterlo confermare, lasciando la barra in stato sporco e la scheda ferma
     * dov'era. Meglio non iniziare — vedi [firstStep].
     *
     * `minSdk` del progetto e' 28, quindi Android 9 e 10 restano col vecchio
     * comportamento (overlay + HOME) in modo esplicito e documentato.
     */
    const val MIN_SDK_FOR_COMMIT = 30

    /**
     * Quanto aspettare dopo aver richiesto il focus prima di ritentare la
     * scrittura.
     *
     * Il focus della barra degli indirizzi non e' sincrono: il browser reagisce
     * con la propria animazione di "modalita' modifica" e l'albero
     * accessibility viene ripubblicato solo dopo. 250ms e' la stessa scala dei
     * re-check gia' usati nel service (`scheduleBackFallbackHome` 600ms,
     * `scheduleGhostRecheck` 800ms) tenuta piu' bassa perche' qui l'utente sta
     * gia' guardando l'overlay e il HOME e' in attesa di questo esito.
     */
    const val FOCUS_SETTLE_DELAY_MS = 250L

    /**
     * Tentativi totali (scrittura diretta + un solo ritento dopo il focus).
     *
     * Il tetto esiste per lo stesso motivo di `MAX_SILENCE_ATTEMPTS`: senza,
     * un browser che rifiuta sistematicamente `ACTION_SET_TEXT` terrebbe il
     * HOME appeso per sempre, e il blocco non verrebbe MAI applicato — cioe' un
     * fallimento di questa feature diventerebbe un buco di enforcement.
     */
    const val MAX_ATTEMPTS = 2

    /**
     * Finestra in cui il dismiss automatico dell'overlay resta sospeso per il
     * package che stiamo liberando.
     *
     * Serve perche' la navigazione verso [NEUTRAL_URL] genera un
     * `TYPE_WINDOW_CONTENT_CHANGED`, che rientra in `checkAppBlocking`: il
     * browser come *app* non e' bloccato da nessun profilo, quindi il ramo
     * "nessun profilo blocca questo pkg" smonterebbe l'overlay appena mostrato.
     *
     * Prima di questa feature quel ramo si auto-guariva — la scheda era ancora
     * sul dominio bloccato, quindi il `checkWebsiteBlocking` subito successivo
     * ri-mostrava l'overlay. Ora non piu': su `about:blank` non c'e' piu' nessun
     * match, e senza la sospensione l'overlay resterebbe smontato per sempre,
     * lasciando l'utente in home senza aver mai visto perche'.
     *
     * La finestra deve coprire l'intera sequenza — scrittura, eventuale ritento,
     * HOME e gli eventi di coda che il browser emette mentre passa in background
     * — ed e' per questo che va lasciata SCADERE da sola invece di essere chiusa
     * quando la neutralizzazione riesce. E' limitata a un package e a questo
     * intervallo, e puo' solo TENERE l'overlay piu' a lungo: mai mostrarne uno
     * di meno.
     */
    const val SUPPRESS_DISMISS_MS = 1_500L

    /** Cosa fare con il nodo barra-indirizzi appena esaminato. */
    enum class Step {
        /// Nessuna strada praticabile: il chiamante degrada a overlay + HOME.
        UNSUPPORTED,

        /// Chiedi il focus al nodo e riprova fra [FOCUS_SETTLE_DELAY_MS].
        FOCUS_THEN_RETRY,

        /// Scrivi [NEUTRAL_URL] e conferma con l'azione IME.
        WRITE_AND_COMMIT,
    }

    /**
     * Primo passo per un nodo barra-indirizzi appena trovato.
     *
     * @param attempt tentativi gia' spesi (0-based). Serve perche' anche questo
     *   ramo puo' chiedere [Step.FOCUS_THEN_RETRY]: senza il tetto, un nodo che
     *   non espone mai `ACTION_SET_TEXT` continuerebbe a chiedere il focus
     *   all'infinito e il HOME — appeso alla callback — non arriverebbe MAI.
     * @param sdkInt API level corrente (vedi [MIN_SDK_FOR_COMMIT]).
     * @param clearUrlAllowed il flag `clearUrl` del [BrowserConfig]. Era
     *   parsato ma inutilizzato da sempre: e' la dichiarazione, per browser,
     *   che quel nodo e' una barra scrivibile e non un titolo di pagina in sola
     *   lettura (es. `mx.browser` → `wt_title`, DuckDuckGo, Dolphin). Onorarlo
     *   qui evita di scrivere in un nodo che non naviga nulla.
     * @param nodeEditable `isEditable`. La barra vera e' un EditText; gli
     *   `:id/origin` di Chrome (il chip del dominio) sono TextView in sola
     *   lettura e vanno scartati a favore del config successivo.
     * @param supportsSetText se il nodo espone davvero `ACTION_SET_TEXT`.
     * @param nodeFocusable / @param nodeFocused stato del focus di input.
     *
     * Si prova la scrittura DIRETTA prima del focus, non per ottimizzare ma per
     * non far comparire la tastiera: dare il focus alla barra fa aprire l'IME,
     * che e' `TYPE_INPUT_METHOD` e quindi si disegna SOPRA l'overlay di blocco
     * (`TYPE_APPLICATION_OVERLAY`). Se la scrittura diretta basta, l'utente non
     * vede nessun lampo di tastiera.
     */
    fun firstStep(
        attempt: Int,
        sdkInt: Int,
        clearUrlAllowed: Boolean,
        nodeEditable: Boolean,
        supportsSetText: Boolean,
        nodeFocusable: Boolean,
        nodeFocused: Boolean,
    ): Step {
        if (sdkInt < MIN_SDK_FOR_COMMIT) return Step.UNSUPPORTED
        if (!clearUrlAllowed) return Step.UNSUPPORTED
        if (!nodeEditable) return Step.UNSUPPORTED
        if (supportsSetText) return Step.WRITE_AND_COMMIT
        if (nodeFocusable && !nodeFocused && attempt + 1 < MAX_ATTEMPTS) {
            return Step.FOCUS_THEN_RETRY
        }
        return Step.UNSUPPORTED
    }

    /**
     * Cosa fare quando la scrittura e' andata ma la CONFERMA e' stata rifiutata.
     *
     * Tipicamente significa che la barra non era in modalita' modifica: il testo
     * e' stato accettato dal `TextView` ma `onEditorAction` non ha navigato. Un
     * giro di focus e' l'unica mossa che puo' cambiare l'esito, e solo se il
     * nodo il focus non ce l'aveva gia': se ce l'aveva ed e' fallito comunque,
     * ritentare produrrebbe solo lo stesso rifiuto piu' un lampo di tastiera.
     */
    fun stepAfterFailedCommit(
        attempt: Int,
        nodeFocusable: Boolean,
        nodeFocused: Boolean,
    ): Step {
        if (attempt + 1 >= MAX_ATTEMPTS) return Step.UNSUPPORTED
        if (!nodeFocusable || nodeFocused) return Step.UNSUPPORTED
        return Step.FOCUS_THEN_RETRY
    }
}
