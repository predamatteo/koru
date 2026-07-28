package com.dev.koru.service

import android.media.AudioManager
import com.dev.koru.overlay.BlockReason
import com.dev.koru.service.MediaSilencePolicy.SilenceIntent
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Truth table di [MediaSilencePolicy].
 *
 * Il bug che questa policy chiude era strutturale: un solo path di blocco su
 * otto silenziava il media. Il test piu' importante del file non e' un caso
 * particolare ma [everyBlockReason_isMapped]: fallisce se qualcuno aggiunge un
 * [BlockReason] senza decidere che semantica di silenziamento ha.
 */
class MediaSilencePolicyTest {

    // --- intentFor -----------------------------------------------------------

    @Test
    fun everyBlockReason_isMapped() {
        // Nessun reason deve produrre NONE quando l'app bloccata e' in
        // foreground: se un giorno servisse un'eccezione, va scritta
        // esplicitamente qui insieme al perche'.
        BlockReason.values().forEach { reason ->
            assertThat(MediaSilencePolicy.intentFor(reason, blockedPkgIsForeground = true))
                .isEqualTo(SilenceIntent.PAUSE_RESUMABLE)
        }
    }

    @Test
    fun appBlocked_inForeground_pausesResumable() {
        // Il caso del bug: link YouTube aperto da un'altra app.
        assertThat(
            MediaSilencePolicy.intentFor(BlockReason.APP_BLOCKED, blockedPkgIsForeground = true),
        ).isEqualTo(SilenceIntent.PAUSE_RESUMABLE)
    }

    @Test
    fun sectionBlocked_inForeground_pausesResumable() {
        // Reels e Shorts: contenuto per definizione con audio.
        assertThat(
            MediaSilencePolicy.intentFor(BlockReason.SECTION_BLOCKED, blockedPkgIsForeground = true),
        ).isEqualTo(SilenceIntent.PAUSE_RESUMABLE)
    }

    @Test
    fun preLaunch_notForeground_isSurgicalOnly() {
        // L'app non e' ancora aperta: chi sta suonando ORA e' quasi certamente
        // qualcun altro (la musica dell'utente). Il layer focus, che non e'
        // targettizzato, va saltato.
        BlockReason.values().forEach { reason ->
            assertThat(MediaSilencePolicy.intentFor(reason, blockedPkgIsForeground = false))
                .isEqualTo(SilenceIntent.SURGICAL_ONLY)
        }
    }

    // --- nextProbeDelayMs ----------------------------------------------------

    @Test
    fun probeDelays_areIncreasingThenExhausted() {
        assertThat(MediaSilencePolicy.nextProbeDelayMs(0)).isEqualTo(300L)
        assertThat(MediaSilencePolicy.nextProbeDelayMs(1)).isEqualTo(900L)
        assertThat(MediaSilencePolicy.nextProbeDelayMs(2)).isEqualTo(2000L)
        // Esaurite: null e' il segnale di stop, non un ritardo 0 che
        // rischedulerebbe all'infinito.
        assertThat(MediaSilencePolicy.nextProbeDelayMs(3)).isNull()
        assertThat(MediaSilencePolicy.nextProbeDelayMs(99)).isNull()
    }

    @Test
    fun probeDelays_negativeAttemptIsNull() {
        // Difensivo: un indice negativo non deve lanciare.
        assertThat(MediaSilencePolicy.nextProbeDelayMs(-1)).isNull()
    }

    @Test
    fun probeWindow_coversTypicalPlayerStart() {
        // Le sonde devono coprire almeno i ~2s entro cui un player parte dopo
        // la comparsa dell'Activity: e' l'intera ragione per cui esistono.
        assertThat(MediaSilencePolicy.PROBE_DELAYS_MS.max()).isAtLeast(2000L)
    }

    // --- shouldReacquire -----------------------------------------------------

    @Test
    fun reacquires_onLoss_whileSessionActive() {
        // IL fix: il player strappa il focus, noi lo ri-chiediamo.
        assertThat(
            MediaSilencePolicy.shouldReacquire(
                focusChange = MediaSilencePolicy.AUDIOFOCUS_LOSS,
                sessionActive = true,
                attempt = 0,
            ),
        ).isTrue()
        assertThat(
            MediaSilencePolicy.shouldReacquire(
                focusChange = MediaSilencePolicy.AUDIOFOCUS_LOSS_TRANSIENT,
                sessionActive = true,
                attempt = 1,
            ),
        ).isTrue()
    }

    @Test
    fun doesNotReacquire_afterRelease() {
        // Un LOSS in ritardo (arrivato dopo il dismiss) non deve resuscitare
        // il silenziamento: lascerebbe il telefono muto senza overlay.
        assertThat(
            MediaSilencePolicy.shouldReacquire(
                focusChange = MediaSilencePolicy.AUDIOFOCUS_LOSS,
                sessionActive = false,
                attempt = 0,
            ),
        ).isFalse()
    }

    @Test
    fun doesNotReacquire_pastAttemptCap() {
        // Fine della guerra del focus.
        assertThat(
            MediaSilencePolicy.shouldReacquire(
                focusChange = MediaSilencePolicy.AUDIOFOCUS_LOSS,
                sessionActive = true,
                attempt = MediaSilencePolicy.MAX_SILENCE_ATTEMPTS,
            ),
        ).isFalse()
    }

    @Test
    fun doesNotReacquire_onDuckOrGain() {
        // CAN_DUCK non e' una perdita del focus e noi non riproduciamo nulla:
        // re-armare sarebbe una guerra gratuita.
        assertThat(
            MediaSilencePolicy.shouldReacquire(
                focusChange = MediaSilencePolicy.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
                sessionActive = true,
                attempt = 0,
            ),
        ).isFalse()
        // GAIN significa che il focus e' NOSTRO: niente da riconquistare.
        assertThat(
            MediaSilencePolicy.shouldReacquire(
                focusChange = MediaSilencePolicy.AUDIOFOCUS_GAIN,
                sessionActive = true,
                attempt = 0,
            ),
        ).isFalse()
    }

    // --- allineamento con l'ABI Android --------------------------------------

    @Test
    fun focusConstants_matchAudioManager() {
        // [MediaSilencePolicy] ri-dichiara queste costanti per restare priva di
        // import Android (test puri). Sono `static final int`, quindi inlined a
        // compile time e leggibili anche senza Robolectric: se Android le
        // cambiasse, o se qualcuno le ricopiasse male, il disallineamento
        // fallisce qui invece che silenziosamente on-device.
        assertThat(MediaSilencePolicy.AUDIOFOCUS_GAIN).isEqualTo(AudioManager.AUDIOFOCUS_GAIN)
        assertThat(MediaSilencePolicy.AUDIOFOCUS_LOSS).isEqualTo(AudioManager.AUDIOFOCUS_LOSS)
        assertThat(MediaSilencePolicy.AUDIOFOCUS_LOSS_TRANSIENT)
            .isEqualTo(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT)
        assertThat(MediaSilencePolicy.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK)
            .isEqualTo(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK)
    }
}
