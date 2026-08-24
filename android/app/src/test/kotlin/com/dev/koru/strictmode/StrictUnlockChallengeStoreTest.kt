package com.dev.koru.strictmode

import com.dev.koru.contract.BlockingContract
import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.util.Random

/**
 * Test della sfida a memoria che autorizza il downgrade della strict-mode mask
 * al posto del backdoor code.
 *
 * Le proprietà che contano davvero, in ordine di gravità se si rompessero:
 * - **alzare la mask non passa di qui** (`NotADowngrade`): se questo ramo
 *   sparisse, aggiungere una restrizione chiederebbe un puzzle e la direzione
 *   fail-secure diventerebbe faticosa;
 * - **una risposta sbagliata brucia la sfida**: è ciò che rende il brute force
 *   inutile, molto più del cooldown;
 * - **la difficoltà segue la gravità**: uscire del tutto costa più di allentare
 *   un singolo bit;
 * - **TTL su clock monotonico** e **una sola sfida viva alla volta**.
 *
 * Il clock è iniettato ovunque (`nowElapsedMs`), come in [UnblockTokenStoreTest],
 * così i test non dipendono da `SystemClock.elapsedRealtime`. Il [Random] è
 * seminato dove serve determinismo.
 */
class StrictUnlockChallengeStoreTest {

    private val all = BlockingContract.ALL_OPTIONS_ENABLED
    private val settings = BlockingContract.BLOCK_SETTINGS
    private val recents = BlockingContract.BLOCK_RECENT_APPS

    @Before
    fun setUp() {
        StrictUnlockChallengeStore.reset()
        UnblockTokenStore.invalidate()
    }

    @After
    fun tearDown() {
        StrictUnlockChallengeStore.reset()
        UnblockTokenStore.invalidate()
    }

    private fun issued(outcome: StrictUnlockChallengeStore.StartOutcome) =
        (outcome as StrictUnlockChallengeStore.StartOutcome.Issued).spec

    // ─── direzione ──────────────────────────────────────────────────────────

    @Test
    fun start_raisingTheMask_isNotADowngrade() {
        // Da "solo settings" a "settings + recenti": si aggiunge, non si toglie.
        val outcome = StrictUnlockChallengeStore.start(
            oldMask = settings,
            newMask = settings or recents,
            nowElapsedMs = 1_000L,
        )
        assertThat(outcome).isInstanceOf(
            StrictUnlockChallengeStore.StartOutcome.NotADowngrade::class.java,
        )
    }

    @Test
    fun start_sameMask_isNotADowngrade() {
        val outcome = StrictUnlockChallengeStore.start(all, all, nowElapsedMs = 1_000L)
        assertThat(outcome).isInstanceOf(
            StrictUnlockChallengeStore.StartOutcome.NotADowngrade::class.java,
        )
    }

    @Test
    fun start_clearingOneBit_issuesAChallenge() {
        val outcome = StrictUnlockChallengeStore.start(
            oldMask = all,
            newMask = all and settings.inv(),
            nowElapsedMs = 1_000L,
        )
        assertThat(outcome).isInstanceOf(
            StrictUnlockChallengeStore.StartOutcome.Issued::class.java,
        )
    }

    // ─── difficoltà proporzionata ───────────────────────────────────────────

    @Test
    fun start_fullExit_isHarderThanLooseningOneBit() {
        val loosen = issued(
            StrictUnlockChallengeStore.start(all, all and settings.inv(), nowElapsedMs = 1_000L),
        )
        StrictUnlockChallengeStore.reset()
        val exit = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))

        assertThat(exit.sequenceSlots.size).isGreaterThan(loosen.sequenceSlots.size)
        assertThat(exit.gridSize).isGreaterThan(loosen.gridSize)
        // Meno tempo per guardare la sequenza, non di più.
        assertThat(exit.memorizeMs).isLessThan(loosen.memorizeMs)
    }

    @Test
    fun start_clearingEveryActiveBit_countsAsFullExit_evenIfNewMaskIsNotZero() {
        // oldMask ha solo `settings` acceso; newMask spegne quello e accende un
        // bit che prima non c'era. Nessun bit attivo sopravvive ⇒ è un'uscita.
        val exit = issued(
            StrictUnlockChallengeStore.start(
                oldMask = settings,
                newMask = recents,
                nowElapsedMs = 1_000L,
            ),
        )
        StrictUnlockChallengeStore.reset()
        val loosen = issued(
            StrictUnlockChallengeStore.start(all, all and settings.inv(), nowElapsedMs = 1_000L),
        )
        assertThat(exit.sequenceSlots.size).isGreaterThan(loosen.sequenceSlots.size)
    }

    // ─── forma della sfida ──────────────────────────────────────────────────

    @Test
    fun spec_slotsAreDistinctAndInsideTheGrid() {
        repeat(50) { seed ->
            StrictUnlockChallengeStore.reset()
            val spec = issued(
                StrictUnlockChallengeStore.start(
                    all,
                    0,
                    nowElapsedMs = 1_000L,
                    random = Random(seed.toLong()),
                ),
            )
            assertThat(spec.sequenceSlots).hasSize(spec.sequenceSlots.toSet().size)
            assertThat(spec.sequenceSlots.all { it in 0 until spec.gridSize }).isTrue()
            assertThat(spec.gridSize % spec.columns).isEqualTo(0)
            // Serve spazio per almeno un sosia per bersaglio, altrimenti la
            // griglia è tutta bersagli e il puzzle si risolve a occhio.
            assertThat(spec.gridSize - spec.sequenceSlots.size)
                .isAtLeast(spec.sequenceSlots.size)
        }
    }

    @Test
    fun start_twoChallengesInARow_differ() {
        // Con SecureRandom reale: 40 emissioni non devono dare sempre la stessa
        // sequenza (un generatore degenere passerebbe tutti gli altri test).
        val seen = mutableSetOf<List<Int>>()
        repeat(40) {
            StrictUnlockChallengeStore.reset()
            seen += issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))
                .sequenceSlots
        }
        assertThat(seen.size).isGreaterThan(10)
    }

    // ─── verifica ───────────────────────────────────────────────────────────

    @Test
    fun verify_correctAnswer_returnsTheTargetMask() {
        val target = all and settings.inv()
        val spec = issued(StrictUnlockChallengeStore.start(all, target, nowElapsedMs = 1_000L))
        assertThat(StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = 2_000L))
            .isEqualTo(target)
    }

    @Test
    fun verify_isSingleUse_secondAttemptFails() {
        val spec = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))
        assertThat(StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = 2_000L))
            .isNotNull()
        assertThat(StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = 3_000L))
            .isNull()
    }

    @Test
    fun verify_wrongOrder_fails() {
        val spec = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))
        val reversed = spec.sequenceSlots.reversed()
        // Se per caso la sequenza fosse palindroma il test non direbbe nulla.
        assertThat(reversed).isNotEqualTo(spec.sequenceSlots)
        assertThat(StrictUnlockChallengeStore.verify(reversed, nowElapsedMs = 2_000L)).isNull()
    }

    @Test
    fun verify_wrongAnswer_burnsTheChallenge() {
        // È LA difesa contro il brute force: sbagliare non lascia in piedi la
        // stessa sfida da ritentare, ne serve una nuova (con altra risposta).
        val spec = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))
        assertThat(StrictUnlockChallengeStore.verify(listOf(99), nowElapsedMs = 2_000L)).isNull()
        assertThat(StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = 3_000L))
            .isNull()
    }

    @Test
    fun verify_afterTtl_fails() {
        val spec = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))
        val tooLate = 1_000L + StrictUnlockChallengeStore.TTL_MS + 1L
        assertThat(StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = tooLate))
            .isNull()
    }

    @Test
    fun verify_withoutAnyChallenge_fails() {
        assertThat(StrictUnlockChallengeStore.verify(listOf(0, 1, 2), nowElapsedMs = 1_000L))
            .isNull()
    }

    @Test
    fun start_invalidatesThePreviousChallenge() {
        val first = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 1_000L))
        val second = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = 2_000L))
        // La risposta vecchia non vale più (se per caso coincidono, il test non
        // afferma nulla di sbagliato: la seconda è comunque quella viva).
        if (first.sequenceSlots != second.sequenceSlots) {
            assertThat(
                StrictUnlockChallengeStore.verify(first.sequenceSlots, nowElapsedMs = 3_000L),
            ).isNull()
        }
    }

    // ─── cooldown ───────────────────────────────────────────────────────────

    @Test
    fun cooldown_kicksInAfterRepeatedFailures_andExpires() {
        var now = 1_000L
        repeat(StrictUnlockChallengeStore.MAX_CONSECUTIVE_FAILURES) {
            StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = now)
            assertThat(StrictUnlockChallengeStore.verify(listOf(-1), nowElapsedMs = now)).isNull()
            now += 10L
        }

        assertThat(StrictUnlockChallengeStore.cooldownRemainingMs(now)).isGreaterThan(0L)
        assertThat(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = now))
            .isInstanceOf(StrictUnlockChallengeStore.StartOutcome.Cooldown::class.java)

        val afterCooldown = now + StrictUnlockChallengeStore.COOLDOWN_MS + 1L
        assertThat(StrictUnlockChallengeStore.cooldownRemainingMs(afterCooldown)).isEqualTo(0L)
        assertThat(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = afterCooldown))
            .isInstanceOf(StrictUnlockChallengeStore.StartOutcome.Issued::class.java)
    }

    @Test
    fun cooldown_counterResetsOnSuccess() {
        var now = 1_000L
        // Un fallimento sotto soglia, poi un successo: il contatore riparte da
        // zero, altrimenti fallimenti sparsi nel tempo si sommerebbero fino a
        // un cooldown immeritato.
        repeat(StrictUnlockChallengeStore.MAX_CONSECUTIVE_FAILURES - 1) {
            StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = now)
            StrictUnlockChallengeStore.verify(listOf(-1), nowElapsedMs = now)
            now += 10L
        }
        val spec = issued(StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = now))
        assertThat(StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = now))
            .isNotNull()

        // Ora servono di nuovo MAX fallimenti pieni per il cooldown.
        repeat(StrictUnlockChallengeStore.MAX_CONSECUTIVE_FAILURES - 1) {
            now += 10L
            StrictUnlockChallengeStore.start(all, 0, nowElapsedMs = now)
            StrictUnlockChallengeStore.verify(listOf(-1), nowElapsedMs = now)
        }
        assertThat(StrictUnlockChallengeStore.cooldownRemainingMs(now)).isEqualTo(0L)
    }

    // ─── integrazione col token ─────────────────────────────────────────────

    @Test
    fun tokenIssuedForOneMask_isRejectedForAnother() {
        // Il puzzle "leggero" per spegnere un bit non deve autorizzare l'uscita
        // completa: è il motivo per cui il token è vincolato alla mask.
        val target = all and settings.inv()
        val spec = issued(StrictUnlockChallengeStore.start(all, target, nowElapsedMs = 1_000L))
        val mask = StrictUnlockChallengeStore.verify(spec.sequenceSlots, nowElapsedMs = 1_100L)
        assertThat(mask).isEqualTo(target)

        val token = UnblockTokenStore.issue(nowElapsedMs = 1_100L, boundMask = mask)
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = 1_200L, targetMask = 0))
            .isFalse()
    }

    @Test
    fun tokenIssuedForOneMask_isAcceptedForThatMask() {
        val target = all and recents.inv()
        val token = UnblockTokenStore.issue(nowElapsedMs = 1_000L, boundMask = target)
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = 1_100L, targetMask = target))
            .isTrue()
    }

    @Test
    fun backdoorToken_staysUnbound_andWorksForAnyMask() {
        // Regressione: il path del backdoor code emette token generici e non
        // deve essere stretto dal binding introdotto per il puzzle.
        val token = UnblockTokenStore.issue(nowElapsedMs = 1_000L)
        assertThat(UnblockTokenStore.consume(token, nowElapsedMs = 1_100L, targetMask = 0))
            .isTrue()
    }
}
