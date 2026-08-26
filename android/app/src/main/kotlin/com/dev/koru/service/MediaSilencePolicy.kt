package com.dev.koru.service

import com.dev.koru.overlay.BlockReason

/**
 * Decisione PURA del silenziamento media: "quando Koru blocca qualcosa, come va
 * zittito il media che sta suonando?".
 *
 * ## Perche' esiste (il bug che l'ha motivata)
 * L'overlay di blocco e' `TYPE_APPLICATION_OVERLAY` + `FLAG_NOT_FOCUSABLE`:
 * l'Activity sotto resta RESUMED e continua a riprodurre. Aprendo un link
 * YouTube da un'altra app l'overlay compariva correttamente ma l'audio del
 * video partiva lo stesso — e lo stesso valeva per un reel Instagram o un
 * video TikTok.
 *
 * La causa non era il meccanismo (l'audio focus) ma DOVE e QUANDO veniva usato:
 * una sola call-site su otto path di blocco, sparata all'arrivo del
 * `TYPE_WINDOW_STATE_CHANGED` — cioe' quando l'Activity compare ma il player
 * non e' ancora partito. In quell'istante non c'e' nessun focus holder da
 * spodestare; mezzo secondo dopo e' il player a chiedere il focus, e siccome
 * l'audio focus e' uno stack in cui l'ultimo che chiede vince, se lo prende.
 *
 * La DECISIONE — "questo blocco silenzia? e con che semantica?" — e' una
 * funzione pura dei suoi input, quindi vive qui ed e' unit-testabile senza
 * Robolectric (stesso ragionamento di [WatchedPackageCalculator] e
 * [BlockPolicyEvaluator]). Il side-effect — parlare con AudioManager e con le
 * MediaSession — sta in [MediaSilencer].
 */
object MediaSilencePolicy {

    /**
     * Come va silenziato il media per un dato blocco.
     *
     * La distinzione non e' "quanto e' severo il blocco" ma "chi sta suonando":
     * il layer audio-focus NON e' targettizzato (mette in pausa chiunque stia
     * riproducendo, anche lo Spotify dell'utente), quindi va usato solo quando
     * l'app bloccata e' davvero quella in foreground.
     */
    enum class SilenceIntent {
        /// Non fare nulla.
        NONE,

        /// Solo il layer chirurgico (MediaSession del package bloccato). Usato
        /// quando l'app bloccata NON e' in foreground — tipicamente il blocco
        /// pre-lancio, dove l'app non e' ancora aperta: un audio in corso in
        /// quel momento e' quasi certamente di qualcun altro e rubargli il
        /// focus sarebbe puro danno collaterale.
        SURGICAL_ONLY,

        /// Chirurgico se disponibile, altrimenti audio focus. "Resumable"
        /// perche' il focus e' chiesto TRANSIENT: al rilascio chi e' stato
        /// messo in pausa riceve `AUDIOFOCUS_GAIN` e riprende da solo. E' cio'
        /// che fa ripartire il video sul deep link esatto dopo "Apri comunque",
        /// senza che Koru debba rilanciare nulla.
        PAUSE_RESUMABLE,
    }

    /**
     * Costanti `AudioManager` ri-dichiarate per tenere questo object privo di
     * import Android (test JUnit puri, niente Robolectric). Sono parte dell'ABI
     * pubblica e stabile di Android; `MediaSilencePolicyTest` asserisce che
     * coincidano ancora con quelle vere, cosi' un eventuale disallineamento
     * fallisce in CI invece che silenziosamente on-device.
     */
    const val AUDIOFOCUS_GAIN = 1
    const val AUDIOFOCUS_LOSS = -1
    const val AUDIOFOCUS_LOSS_TRANSIENT = -2
    const val AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK = -3

    /**
     * Tetto ai tentativi di acquisizione del focus per sessione di
     * silenziamento (acquire iniziale + sonde + re-arm su LOSS).
     *
     * Serve a impedire la "guerra del focus": un player che ri-chiede il focus
     * ogni volta che glielo togliamo produrrebbe un ping-pong infinito con blip
     * audio percepibili. Dopo il cap Koru si arrende e logga `giveup` — meglio
     * un fallimento diagnosticabile che un loop.
     */
    const val MAX_SILENCE_ATTEMPTS = 4

    /**
     * Finestra massima di detenzione del silenzio, oltre la quale il
     * [MediaSilencer] auto-rilascia anche senza un dismiss.
     *
     * E' una rete di sicurezza per l'invariante "silenzio detenuto <=> overlay
     * visibile": se un dismiss si perde (crash del service, race), senza questo
     * l'utente resterebbe col telefono muto senza capire perche'.
     */
    const val MAX_HOLD_MS = 5 * 60 * 1000L

    /**
     * Che semantica di silenziamento applicare a un blocco.
     *
     * @param reason il motivo del blocco; oggi TUTTI i reason silenziano —
     *   l'enumerazione esplicita serve a rendere `when` esaustivo, cosi' un
     *   nuovo [BlockReason] non compila finche' non si decide che semantica ha
     *   (il bug originale nasce proprio da un path aggiunto e mai strumentato).
     * @param blockedPkgIsForeground se il package bloccato e' davvero in
     *   foreground ORA. False nel path pre-lancio.
     */
    fun intentFor(reason: BlockReason, blockedPkgIsForeground: Boolean): SilenceIntent {
        if (!blockedPkgIsForeground) return SilenceIntent.SURGICAL_ONLY
        return when (reason) {
            BlockReason.APP_BLOCKED,
            BlockReason.SECTION_BLOCKED,
            BlockReason.WEBSITE_BLOCKED,
            BlockReason.USAGE_LIMIT,
            BlockReason.BYPASS_EXPIRED,
            -> SilenceIntent.PAUSE_RESUMABLE
        }
    }

    /// I ritardi delle sonde, crescenti per coprire player lenti senza
    /// martellare quelli veloci.
    val PROBE_DELAYS_MS = listOf(300L, 900L, 2000L)

    /**
     * Ritardo della prossima sonda di ri-acquisizione, o null se le sonde sono
     * esaurite.
     *
     * Le sonde esistono perche' il player parte DOPO di noi: l'evento finestra
     * arriva quando l'Activity compare, il player chiede il focus tipicamente
     * entro 0,5-3s. Sono `postDelayed` one-shot cancellati al release — non un
     * polling loop, quindi compatibili con i vincoli batteria documentati in
     * [LockRunnable.checkAndBlock]. Stesso pattern di
     * `scheduleBackFallbackHome` / `scheduleGhostRecheck`.
     *
     * @param attempt indice della sonda gia' eseguite (0-based).
     */
    fun nextProbeDelayMs(attempt: Int): Long? =
        PROBE_DELAYS_MS.getOrNull(attempt)

    /**
     * Se reagire a un `onAudioFocusChange` ri-chiedendo il focus.
     *
     * E' il cuore del fix: il listener era dichiaratamente no-op, quindi quando
     * il player strappava il focus a Koru nessuno se ne accorgeva e non c'era
     * un secondo tentativo.
     *
     * `LOSS_TRANSIENT_CAN_DUCK` e' deliberatamente ESCLUSO: significa che
     * l'altra app ci chiede solo di abbassare il volume, non e' una perdita del
     * focus, e siccome noi non riproduciamo nulla non c'e' niente da
     * riconquistare — re-armare li' sarebbe solo una guerra gratuita.
     *
     * @param sessionActive se una sessione di silenziamento e' ancora aperta.
     *   False dopo il release: un LOSS in ritardo non deve resuscitare nulla.
     * @param attempt tentativi gia' spesi in questa sessione.
     */
    fun shouldReacquire(focusChange: Int, sessionActive: Boolean, attempt: Int): Boolean {
        if (!sessionActive) return false
        if (attempt >= MAX_SILENCE_ATTEMPTS) return false
        return focusChange == AUDIOFOCUS_LOSS || focusChange == AUDIOFOCUS_LOSS_TRANSIENT
    }
}
