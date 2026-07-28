package com.dev.koru.service

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import com.dev.koru.diagnostics.BlackBox
import com.dev.koru.service.MediaSilencePolicy.SilenceIntent

/**
 * Porta verso l'audio focus di sistema. Astratta per rendere [MediaSilencer]
 * testabile senza Robolectric: l'impl reale e' [AndroidAudioFocusPort].
 */
interface AudioFocusPort {
    /**
     * Chiede il focus audio. Ritorna true SOLO se e' stato concesso.
     *
     * Il valore di ritorno non e' una formalita': su Android 15+ con targetSdk
     * 35 la richiesta FALLISCE se l'app non e' top app ne' ha un foreground
     * service attivo. Il codice precedente lo ignorava e marcava comunque il
     * focus come detenuto, rendendo ogni tentativo successivo un no-op.
     */
    fun request(onFocusChange: (Int) -> Unit): Boolean

    /// Rilascia il focus se detenuto. Idempotente.
    fun abandon(): Boolean
}

/**
 * Porta verso le MediaSession attive — il layer "chirurgico", l'unico che puo'
 * mettere in pausa ESATTAMENTE il package bloccato senza toccare la musica
 * dell'utente. Default [NoOp]: il silenziamento funziona anche senza.
 */
interface MediaSessionPort {
    /// Mette in pausa le sessioni di [packageName]. True se ne ha pausata almeno una.
    fun pause(packageName: String): Boolean

    /// Riprende le sessioni di [packageName]. Chiamata SOLO se siamo stati noi a pausarle.
    fun play(packageName: String): Boolean

    object NoOp : MediaSessionPort {
        override fun pause(packageName: String) = false
        override fun play(packageName: String) = false
    }
}

/**
 * Zittisce il media dell'app bloccata finche' un overlay di blocco e' visibile.
 *
 * ## Il bug che risolve
 * L'overlay non mette in pausa nulla: e' `TYPE_APPLICATION_OVERLAY` +
 * `FLAG_NOT_FOCUSABLE`, l'Activity sotto resta RESUMED e continua a
 * riprodurre. Aprendo un link YouTube da un'altra app comparivano overlay E
 * audio; idem per un reel Instagram o un video TikTok.
 *
 * Il vecchio `requestMediaPause()` chiedeva il focus all'arrivo del
 * `TYPE_WINDOW_STATE_CHANGED`, cioe' quando l'Activity compare ma il player
 * non e' ancora partito: non c'era nessun focus holder da spodestare. Mezzo
 * secondo dopo era il player a chiedere il focus e, siccome l'audio focus e'
 * uno stack in cui l'ultimo che chiede vince, se lo prendeva. Il listener era
 * dichiaratamente no-op, quindi nessuno se ne accorgeva, e il guard di
 * idempotenza restava latchato: **un solo tentativo, sparato nel momento
 * peggiore, e nessun secondo tentativo quando il video partiva davvero**.
 *
 * ## Come lo risolve
 * 1. **Chirurgico prima.** Se la MediaSession del package bloccato e'
 *    raggiungibile, `pause()` su quella: zero danno collaterale, e permette un
 *    `play()` deterministico al rilascio.
 * 2. **Focus come fallback.** Non targettizzato (zittisce chiunque suoni),
 *    quindi chiesto TRANSIENT: al rilascio chi e' stato messo in pausa riceve
 *    `AUDIOFOCUS_GAIN` e riprende da solo — inclusa la musica dell'utente
 *    presa in mezzo, e il video stesso dopo "Apri comunque".
 * 3. **Re-arm.** Il listener non e' piu' no-op: se il player ci strappa il
 *    focus lo ri-chiediamo. Piu' sonde a 300/900/2000ms per intercettare i
 *    player che partono in ritardo.
 * 4. **Bounded.** Cap di [MediaSilencePolicy.MAX_SILENCE_ATTEMPTS] tentativi
 *    per evitare il ping-pong col player, e watchdog di
 *    [MediaSilencePolicy.MAX_HOLD_MS] che auto-rilascia se un dismiss si perde.
 *
 * Tutti i timer sono `postDelayed` one-shot cancellati al release: **non e' un
 * polling loop**, coerente coi vincoli batteria di [LockRunnable.checkAndBlock].
 *
 * ## Invariante
 * Silenzio detenuto <=> un overlay di blocco e' visibile. Chiamare [silence]
 * dopo ogni `overlayManager.show(...)` e [release] dopo ogni `dismiss()`.
 *
 * Non thread-safe di proposito: vive sul main thread del service, come
 * l'OverlayManager che lo pilota.
 */
class MediaSilencer(
    private val focus: AudioFocusPort,
    private val sessions: MediaSessionPort = MediaSessionPort.NoOp,
    private val schedule: (Runnable, Long) -> Unit,
    private val cancel: (Runnable) -> Unit,
    private val log: (String) -> Unit = { BlackBox.log(TAG, it) },
) {

    companion object {
        const val TAG = "MEDIA"

        /// Ritardo del `play()` di ripresa dopo il rilascio del focus. Serve a
        /// dare al player il tempo di processare l'`AUDIOFOCUS_GAIN` prima di
        /// riceverne il comando, altrimenti i due si sovrappongono e alcuni
        /// player ignorano il play.
        const val RESUME_DELAY_MS = 150L

        /// Ritardo del re-arm dopo una perdita del focus. Non zero: rientrare
        /// in `requestAudioFocus` dentro il callback di AudioManager e' un modo
        /// affidabile di litigare col sistema.
        const val REARM_DELAY_MS = 50L
    }

    /// Package attualmente silenziato, null se nessuna sessione e' aperta.
    private var held: String? = null

    /// Semantica della sessione corrente (decide se il layer focus e' ammesso).
    private var intent: SilenceIntent = SilenceIntent.NONE

    /// Tentativi di acquisizione del focus spesi in questa sessione (cap in
    /// [MediaSilencePolicy.MAX_SILENCE_ATTEMPTS]).
    private var attempts: Int = 0

    private var focusHeld: Boolean = false

    /// True solo se siamo stati NOI a mettere in pausa via MediaSession: e' la
    /// precondizione del `play()` di ripresa. Non si riprende una riproduzione
    /// che l'utente non aveva avviato.
    private var surgicalPaused: Boolean = false

    private val pending = mutableListOf<Runnable>()

    /// Il package attualmente silenziato (per test e diagnostica).
    fun heldPackage(): String? = held

    /**
     * Apre (o ri-mira) una sessione di silenziamento.
     *
     * Idempotente sullo stesso package: chiamarla a ogni evento finestra
     * ripetuto non ri-schedula nulla. Su un package diverso chiude prima la
     * sessione precedente, cosi' il silenzio non resta appiccicato all'app da
     * cui l'utente e' appena uscito.
     */
    fun silence(packageName: String, intent: SilenceIntent) {
        if (intent == SilenceIntent.NONE) return
        if (held == packageName) return
        if (held != null) release()

        held = packageName
        this.intent = intent
        attempts = 0
        focusHeld = false
        surgicalPaused = false
        log("silence start pkg=$packageName intent=$intent")

        attemptSilence("initial")

        // Sonde: il player parte DOPO di noi. Sono la differenza fra "overlay
        // su e audio che parte lo stesso" e "silenzio".
        var probe = 0
        while (true) {
            val delay = MediaSilencePolicy.nextProbeDelayMs(probe) ?: break
            post(delay) { attemptSilence("probe@${delay}ms") }
            probe++
        }

        // Rete di sicurezza: nessun dismiss deve poter lasciare il telefono muto.
        post(MediaSilencePolicy.MAX_HOLD_MS) {
            log("watchdog max-hold scaduto pkg=$held → release forzato")
            release()
        }
    }

    /**
     * Chiude la sessione: cancella i timer e rilascia il focus.
     *
     * Idempotente: chiamarla senza sessione aperta e' un no-op, cosi' puo'
     * stare incondizionatamente accanto a ogni `dismiss()`.
     *
     * @param resume se riprendere anche la MediaSession che abbiamo messo in
     *   pausa. Default **false**, ed e' il default giusto: il `play()` e' un
     *   comando esplicito che farebbe ripartire l'audio *in background* se
     *   l'app non e' piu' in foreground — esattamente il bug che questa classe
     *   esiste per chiudere. Va passato true solo dove l'utente ha scelto di
     *   restare nell'app (bypass "Apri comunque"), mai su screen-off, cambio
     *   app, watchdog o blocco sopravvenuto.
     *
     *   Il focus TRANSIENT invece si auto-riprende sempre al rilascio, e va
     *   bene: chi lo riottiene lo fa solo se aveva davvero un player in attesa.
     */
    fun release(resume: Boolean = false) {
        val pkg = held ?: return
        held = null
        intent = SilenceIntent.NONE
        attempts = 0

        pending.forEach(cancel)
        pending.clear()

        if (focusHeld) {
            focus.abandon()
            focusHeld = false
            // Chi e' stato messo in pausa dal nostro TRANSIENT riceve ora
            // AUDIOFOCUS_GAIN e riprende da solo: il video sul deep link dopo
            // "Apri comunque", e l'eventuale musica presa in mezzo.
            log("release focus pkg=$pkg")
        }

        if (surgicalPaused) {
            surgicalPaused = false
            if (resume) {
                // Il layer chirurgico non gode della ripresa automatica:
                // l'abbiamo pausato con un comando esplicito, va ripreso con un
                // comando esplicito. Differito perche' il player deve prima
                // digerire il GAIN di cui sopra.
                post(RESUME_DELAY_MS) {
                    log("resume surgical pkg=$pkg")
                    sessions.play(pkg)
                }
            } else {
                log("no-resume pkg=$pkg (sessione chiusa senza bypass)")
            }
        }
    }

    /// Callback del focus: e' il punto in cui il vecchio codice non faceva
    /// nulla, ed e' il motivo per cui l'audio partiva comunque.
    private fun onFocusChange(change: Int) {
        val pkg = held
        if (change == MediaSilencePolicy.AUDIOFOCUS_GAIN) {
            focusHeld = true
            return
        }
        focusHeld = false
        if (!MediaSilencePolicy.shouldReacquire(change, sessionActive = pkg != null, attempt = attempts)) {
            if (pkg != null) log("focus perso (change=$change) pkg=$pkg → giveup dopo $attempts tentativi")
            return
        }
        log("focus perso (change=$change) pkg=$pkg → re-arm")
        post(REARM_DELAY_MS) { attemptSilence("re-arm") }
    }

    /**
     * Un tentativo di silenziamento: chirurgico prima, focus come fallback.
     *
     * Il chirurgico e' ritentato anche se il focus e' gia' nostro: la
     * MediaSession nasce quando il player parte, quindi al primo giro spesso
     * non esiste ancora ed e' proprio una sonda successiva a trovarla.
     */
    private fun attemptSilence(why: String) {
        val pkg = held ?: return

        if (!surgicalPaused && sessions.pause(pkg)) {
            surgicalPaused = true
            log("surgical pause OK pkg=$pkg ($why)")
        }

        // Il chirurgico ha gia' zittito esattamente il target: chiedere anche
        // il focus aggiungerebbe solo danno collaterale.
        if (surgicalPaused) return
        if (intent != SilenceIntent.PAUSE_RESUMABLE) return
        if (focusHeld) return
        if (attempts >= MediaSilencePolicy.MAX_SILENCE_ATTEMPTS) return

        attempts++
        val granted = focus.request(::onFocusChange)
        focusHeld = granted
        if (granted) {
            log("focus granted pkg=$pkg ($why, tentativo $attempts)")
        } else {
            // Su Android 15+ senza foreground service attivo la richiesta viene
            // rifiutata: prima era invisibile, ora e' diagnosticabile.
            log("focus FAILED pkg=$pkg ($why, tentativo $attempts)")
        }
    }

    private fun post(delayMs: Long, action: () -> Unit) {
        lateinit var r: Runnable
        r = Runnable {
            pending.remove(r)
            action()
        }
        pending.add(r)
        schedule(r, delayMs)
    }
}

/**
 * Impl reale di [AudioFocusPort] su `AudioManager`.
 *
 * `minSdk = 28`, quindi [AudioFocusRequest] (API 26+) e' sempre disponibile:
 * niente branch legacy.
 */
class AndroidAudioFocusPort(private val context: Context) : AudioFocusPort {

    /// Callback corrente, rimpiazzabile senza cambiare l'oggetto listener —
    /// che deve restare stabile perche' identifica la richiesta presso il sistema.
    private var callback: ((Int) -> Unit)? = null

    private val listener = AudioManager.OnAudioFocusChangeListener { change ->
        callback?.invoke(change)
    }

    private var request: AudioFocusRequest? = null

    override fun request(onFocusChange: (Int) -> Unit): Boolean {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        callback = onFocusChange
        return try {
            val req = request ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build(),
                )
                .setOnAudioFocusChangeListener(listener)
                .build()
                .also { request = it }
            am.requestAudioFocus(req) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } catch (e: Exception) {
            BlackBox.log(MediaSilencer.TAG, "requestAudioFocus ha lanciato: ${e.message}")
            false
        }
    }

    override fun abandon(): Boolean {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        val req = request ?: return false
        return try {
            am.abandonAudioFocusRequest(req) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } catch (e: Exception) {
            BlackBox.log(MediaSilencer.TAG, "abandonAudioFocus ha lanciato: ${e.message}")
            false
        }
    }
}
