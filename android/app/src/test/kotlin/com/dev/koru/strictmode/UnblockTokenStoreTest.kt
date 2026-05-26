package com.dev.koru.strictmode

import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * SEC-01 — test del token monouso che autorizza il downgrade della strict-mode
 * mask lato native.
 *
 * Coprono le proprietà di sicurezza centrali:
 * - happy path: token emesso → consumato una volta;
 * - **single-use**: il secondo consumo dello STESSO token fallisce (no replay);
 * - **TTL su clock monotonico**: scade dopo [UnblockTokenStore.TTL_MS] di
 *   `elapsedRealtime`, e uno spostamento del WALL clock non lo estende
 *   (qui simuliamo il monotonic clock iniettando `nowElapsedMs`);
 * - emettere un nuovo token invalida quello precedente;
 * - token nullo/vuoto/sbagliato non sono mai validi;
 * - [UnblockTokenStore.invalidate] revoca un token in sospeso.
 *
 * Il clock monotonico è iniettato (`nowElapsedMs`) così i test sono
 * deterministici e non dipendono da `SystemClock.elapsedRealtime`.
 */
class UnblockTokenStoreTest {

    @Before
    fun setUp() {
        UnblockTokenStore.invalidate()
    }

    @After
    fun tearDown() {
        UnblockTokenStore.invalidate()
    }

    @Test
    fun issueThenConsume_withinTtl_succeedsOnce() {
        val t0 = 1_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        assertThat(token).isNotEmpty()
        // Consumato 30s dopo (entro i 60s di TTL) → valido.
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = t0 + 30_000L)).isTrue()
    }

    @Test
    fun consume_isSingleUse_secondAttemptFails() {
        val t0 = 5_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = t0 + 1_000L)).isTrue()
        // Replay dello stesso token → rifiutato.
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = t0 + 2_000L)).isFalse()
    }

    @Test
    fun consume_afterTtl_fails() {
        val t0 = 2_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        // 60_001ms dopo → oltre il TTL → scaduto.
        assertThat(
            UnblockTokenStore.consume(token, nowElapsedMs = t0 + UnblockTokenStore.TTL_MS + 1L),
        ).isFalse()
    }

    @Test
    fun consume_exactlyAtTtlBoundary_stillValid() {
        val t0 = 3_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        // Esattamente a TTL_MS (age == TTL) → ancora valido (boundary inclusivo).
        assertThat(
            UnblockTokenStore.consume(token, nowElapsedMs = t0 + UnblockTokenStore.TTL_MS),
        ).isTrue()
    }

    @Test
    fun consume_wallClockJumpDoesNotMatter_onlyMonotonicCounts() {
        // Il TTL è su elapsedRealtime (monotonico). Anche se l'utente sposta il
        // WALL clock avanti/indietro, qui contiamo solo il monotonic: passato
        // poco tempo monotonico (1s) → ancora valido a prescindere dal wall.
        val t0 = 10_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = t0 + 1_000L)).isTrue()
    }

    @Test
    fun consume_monotonicGoesBackward_treatedAsExpired() {
        // nowElapsed < issued (impossibile col clock reale, ma difensivo):
        // age negativo → trattato come scaduto, mai valido.
        val t0 = 4_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = t0 - 5_000L)).isFalse()
    }

    @Test
    fun issue_invalidatesPreviousToken() {
        val t0 = 6_000_000L
        val first = UnblockTokenStore.issue(nowElapsedMs = t0)
        val second = UnblockTokenStore.issue(nowElapsedMs = t0 + 100L)
        assertThat(first).isNotEqualTo(second)
        // Il vecchio token non è più valido (un solo token vivo alla volta).
        assertThat(UnblockTokenStore.consume(first, nowElapsedMs = t0 + 200L)).isFalse()
        // Il nuovo sì.
        assertThat(UnblockTokenStore.consume(second, nowElapsedMs = t0 + 200L)).isTrue()
    }

    @Test
    fun consume_nullOrEmptyOrWrong_isNeverValid() {
        val t0 = 7_000_000L
        UnblockTokenStore.issue(nowElapsedMs = t0)
        assertThat(UnblockTokenStore.consume(null, nowElapsedMs = t0 + 1L)).isFalse()
        assertThat(UnblockTokenStore.consume("", nowElapsedMs = t0 + 1L)).isFalse()
        assertThat(UnblockTokenStore.consume("not-the-token", nowElapsedMs = t0 + 1L)).isFalse()
    }

    @Test
    fun consume_withNoOutstandingToken_fails() {
        // Nessun token emesso → qualsiasi consume fallisce.
        assertThat(UnblockTokenStore.consume("whatever", nowElapsedMs = 1L)).isFalse()
    }

    @Test
    fun invalidate_revokesPendingToken() {
        val t0 = 8_000_000L
        val token = UnblockTokenStore.issue(nowElapsedMs = t0)
        UnblockTokenStore.invalidate()
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = t0 + 1L)).isFalse()
    }

    @Test
    fun tokens_areHighEntropyAndDistinct() {
        // 256-bit hex = 64 char; due emissioni consecutive non collidono.
        val a = UnblockTokenStore.issue(nowElapsedMs = 1L)
        val b = UnblockTokenStore.issue(nowElapsedMs = 2L)
        assertThat(a).hasLength(64)
        assertThat(b).hasLength(64)
        assertThat(a).isNotEqualTo(b)
    }
}
