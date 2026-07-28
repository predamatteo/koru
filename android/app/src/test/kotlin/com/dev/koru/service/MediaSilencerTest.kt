package com.dev.koru.service

import com.dev.koru.service.MediaSilencePolicy.SilenceIntent
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Comportamento di [MediaSilencer] con port fake — niente Robolectric: tutta
 * la meccanica (re-arm, sonde, cap, watchdog, ripresa) e' logica pura una volta
 * che AudioManager e MediaSessionManager stanno dietro un'interfaccia.
 *
 * Il test che descrive il bug originale e' [reacquiresFocus_whenPlayerStealsIt]:
 * prima il listener era no-op e quel secondo tentativo non esisteva.
 */
class MediaSilencerTest {

    // --- doppioni di test ----------------------------------------------------

    private class FakeFocusPort(var grantRequests: Boolean = true) : AudioFocusPort {
        var requests = 0
        var abandons = 0
        var callback: ((Int) -> Unit)? = null

        override fun request(onFocusChange: (Int) -> Unit): Boolean {
            requests++
            callback = onFocusChange
            return grantRequests
        }

        override fun abandon(): Boolean {
            abandons++
            return true
        }

        /// Simula il player che strappa il focus a Koru.
        fun stealFocus() = callback?.invoke(MediaSilencePolicy.AUDIOFOCUS_LOSS)
    }

    private class FakeSessionPort(var canPause: Boolean = false) : MediaSessionPort {
        var pauseCalls = mutableListOf<String>()
        var playCalls = mutableListOf<String>()

        override fun pause(packageName: String): Boolean {
            pauseCalls.add(packageName)
            return canPause
        }

        override fun play(packageName: String): Boolean {
            playCalls.add(packageName)
            return true
        }
    }

    /// Handler fake: i task restano in coda finche' [runDue] non li fa scattare.
    private class FakeScheduler {
        val tasks = mutableListOf<Pair<Long, Runnable>>()
        val schedule: (Runnable, Long) -> Unit = { r, d -> tasks.add(d to r) }
        val cancel: (Runnable) -> Unit = { r -> tasks.removeAll { it.second === r } }

        fun runDue(upToMs: Long) {
            var guard = 0
            while (guard++ < 100) {
                val idx = tasks.indexOfFirst { it.first <= upToMs }
                if (idx < 0) return
                tasks.removeAt(idx).second.run()
            }
            throw AssertionError("runDue non converge: probabile loop di rischedulazione")
        }

        fun pendingDelays(): List<Long> = tasks.map { it.first }.sorted()
    }

    private class Fixture(surgicalWorks: Boolean = false, grantFocus: Boolean = true) {
        val focus = FakeFocusPort(grantFocus)
        val sessions = FakeSessionPort(surgicalWorks)
        val scheduler = FakeScheduler()
        val logs = mutableListOf<String>()
        val silencer = MediaSilencer(
            focus = focus,
            sessions = sessions,
            schedule = scheduler.schedule,
            cancel = scheduler.cancel,
            log = { logs.add(it) },
        )
    }

    // --- acquisizione --------------------------------------------------------

    @Test
    fun pauseResumable_requestsFocus() {
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.focus.requests).isEqualTo(1)
        assertThat(f.silencer.heldPackage()).isEqualTo("com.google.android.youtube")
    }

    @Test
    fun surgicalSuccess_skipsFocusEntirely() {
        // Se la MediaSession del target risponde, il focus non serve: e' il
        // layer non targettizzato e ruberebbe l'audio anche a chi non c'entra.
        val f = Fixture(surgicalWorks = true)
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.sessions.pauseCalls).containsExactly("com.google.android.youtube")
        assertThat(f.focus.requests).isEqualTo(0)
    }

    @Test
    fun surgicalOnly_neverRequestsFocus_evenIfSessionMissing() {
        // Path pre-lancio: l'app non e' in foreground, chi suona e' qualcun
        // altro. Meglio non silenziare affatto che silenziare l'innocente.
        val f = Fixture(surgicalWorks = false)
        f.silencer.silence("com.instagram.android", SilenceIntent.SURGICAL_ONLY)
        f.scheduler.runDue(5_000)
        assertThat(f.focus.requests).isEqualTo(0)
    }

    @Test
    fun intentNone_isNoOp() {
        val f = Fixture()
        f.silencer.silence("com.zhiliaoapp.musically", SilenceIntent.NONE)
        assertThat(f.silencer.heldPackage()).isNull()
        assertThat(f.scheduler.tasks).isEmpty()
    }

    // --- il fix del bug ------------------------------------------------------

    @Test
    fun reacquiresFocus_whenPlayerStealsIt() {
        // IL bug: Koru chiede il focus quando l'Activity compare, il player
        // parte mezzo secondo dopo e se lo riprende. Prima nessuno reagiva.
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.focus.requests).isEqualTo(1)

        f.focus.stealFocus()
        f.scheduler.runDue(MediaSilencer.REARM_DELAY_MS)

        assertThat(f.focus.requests).isEqualTo(2)
    }

    @Test
    fun probes_retryWhileTheOverlayIsUp() {
        // Le sonde coprono il player che parte in ritardo: al primo giro il
        // focus fallisce (nessun player ancora), poi riesce.
        val f = Fixture(grantFocus = false)
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.focus.requests).isEqualTo(1)

        f.focus.grantRequests = true
        f.scheduler.runDue(300)
        assertThat(f.focus.requests).isEqualTo(2)
    }

    @Test
    fun surgicalIsRetriedByProbes_becauseTheSessionIsBornLate() {
        // La MediaSession nasce quando il player parte: al primo tentativo
        // spesso non esiste ancora ed e' una sonda a trovarla.
        val f = Fixture(surgicalWorks = false)
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.sessions.pauseCalls).hasSize(1)

        f.sessions.canPause = true
        f.scheduler.runDue(300)
        assertThat(f.sessions.pauseCalls).hasSize(2)
    }

    @Test
    fun attemptsAreCapped_noFocusWar() {
        // Un player che ri-chiede il focus a ogni giro non deve produrre un
        // ping-pong infinito: dopo il cap Koru si arrende.
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        repeat(10) {
            f.focus.stealFocus()
            f.scheduler.runDue(MediaSilencer.REARM_DELAY_MS)
        }
        assertThat(f.focus.requests).isAtMost(MediaSilencePolicy.MAX_SILENCE_ATTEMPTS)
        assertThat(f.logs.any { it.contains("giveup") }).isTrue()
    }

    @Test
    fun lossAfterRelease_doesNotReacquire() {
        // Un LOSS in ritardo non deve resuscitare il silenziamento: lascerebbe
        // il telefono muto senza overlay visibile.
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        val before = f.focus.requests
        f.silencer.release()

        f.focus.stealFocus()
        f.scheduler.runDue(1_000)

        assertThat(f.focus.requests).isEqualTo(before)
    }

    // --- rilascio ------------------------------------------------------------

    @Test
    fun release_abandonsFocusAndIsIdempotent() {
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        f.silencer.release()
        f.silencer.release()
        assertThat(f.focus.abandons).isEqualTo(1)
        assertThat(f.silencer.heldPackage()).isNull()
    }

    @Test
    fun release_withoutResume_neverPlays() {
        // Regressione critica: un play() su un'app non piu' in foreground
        // farebbe ripartire l'audio in background — il bug stesso.
        val f = Fixture(surgicalWorks = true)
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        f.silencer.release()
        f.scheduler.runDue(5_000)
        assertThat(f.sessions.playCalls).isEmpty()
    }

    @Test
    fun release_withResume_playsTheBlockedPackage() {
        // "Apri comunque" da deep link: il video deve ripartire da solo.
        val f = Fixture(surgicalWorks = true)
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        f.silencer.release(resume = true)
        f.scheduler.runDue(MediaSilencer.RESUME_DELAY_MS)
        assertThat(f.sessions.playCalls).containsExactly("com.google.android.youtube")
    }

    @Test
    fun release_withResume_doesNotPlayWhatWeDidNotPause() {
        // Non si avvia una riproduzione che l'utente non aveva avviato: se il
        // silenzio e' passato dal solo audio focus, il GAIN fa gia' tutto.
        val f = Fixture(surgicalWorks = false)
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        f.silencer.release(resume = true)
        f.scheduler.runDue(5_000)
        assertThat(f.sessions.playCalls).isEmpty()
    }

    @Test
    fun release_cancelsEveryPendingTimer() {
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.scheduler.tasks).isNotEmpty()
        f.silencer.release()
        // Nessun timer sopravvive al rilascio: niente sonde orfane, niente
        // watchdog che scatta su una sessione chiusa.
        assertThat(f.scheduler.tasks).isEmpty()
    }

    // --- cambio target e watchdog -------------------------------------------

    @Test
    fun silence_isIdempotentOnSamePackage() {
        // Gli eventi finestra si ripetono: non devono moltiplicare le sonde.
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        val timers = f.scheduler.tasks.size
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.scheduler.tasks).hasSize(timers)
        assertThat(f.focus.requests).isEqualTo(1)
    }

    @Test
    fun silence_onNewPackage_releasesPreviousSession() {
        // Il silenzio non deve restare appiccicato all'app da cui l'utente e'
        // appena uscito.
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        f.silencer.silence("com.instagram.android", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.focus.abandons).isEqualTo(1)
        assertThat(f.silencer.heldPackage()).isEqualTo("com.instagram.android")
    }

    @Test
    fun watchdog_releasesIfADismissIsLost() {
        // Rete di sicurezza dell'invariante "silenzio <=> overlay visibile".
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        f.scheduler.runDue(MediaSilencePolicy.MAX_HOLD_MS)
        assertThat(f.silencer.heldPackage()).isNull()
        assertThat(f.focus.abandons).isEqualTo(1)
    }

    @Test
    fun watchdog_isScheduledAtMaxHold() {
        val f = Fixture()
        f.silencer.silence("com.google.android.youtube", SilenceIntent.PAUSE_RESUMABLE)
        assertThat(f.scheduler.pendingDelays()).contains(MediaSilencePolicy.MAX_HOLD_MS)
    }
}
