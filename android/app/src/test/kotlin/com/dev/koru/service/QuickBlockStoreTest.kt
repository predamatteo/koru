package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [QuickBlockStore]:
 *  - the IDLE snapshot constants,
 *  - the [QuickBlockStore.Snapshot.shouldBlock] decision matrix,
 *  - file roundtrip via [QuickBlockStore.save] / [QuickBlockStore.read],
 *  - fallback to IDLE on missing or corrupted file,
 *  - [QuickBlockStore.clear] semantics.
 *
 * Robolectric is required: the store writes to `context.filesDir`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class QuickBlockStoreTest {

    private val fileName = "koru_quick_block_state.json"

    @Before
    fun setUp() = cleanup()

    @After
    fun tearDown() = cleanup()

    private fun cleanup() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).delete()
        File(ctx.filesDir, "$fileName.tmp").delete()
        File(ctx.filesDir, "$fileName.lock").delete()
        // ARCH-03: la cache di processo del FileBackedStore sopravvive nel JVM
        // di test; azzerala per isolamento (specie per i test che scrivono un
        // file grezzo legacy/corrotto).
        QuickBlockStore.invalidateCacheForTest()
    }

    // -------- Snapshot.IDLE --------

    @Test
    fun idleSnapshot_hasExpectedDefaults() {
        val idle = QuickBlockStore.Snapshot.IDLE
        assertThat(idle.isActive).isFalse()
        assertThat(idle.isPomodoroMode).isFalse()
        assertThat(idle.isBreakPhase).isFalse()
        assertThat(idle.expiresAt).isEqualTo(0L)
        assertThat(idle.whitelist).isEmpty()
    }

    // -------- Snapshot.shouldBlock --------

    @Test
    fun shouldBlock_idleSnapshot_returnsFalse() {
        val snap = QuickBlockStore.Snapshot.IDLE
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_activeFutureExpiry_pkgNotWhitelisted_returnsTrue() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed"),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isTrue()
    }

    @Test
    fun shouldBlock_activeFutureExpiry_pkgWhitelisted_returnsFalse() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed", "com.x"),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_activeExpired_returnsFalse() {
        // expiresAt <= now ⇒ "in 1..now" path: expired safety valve
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 500L,
            whitelist = emptySet(),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_pomodoroBreakPhase_returnsFalse() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = true,
            expiresAt = 10_000L,
            whitelist = emptySet(),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun shouldBlock_pomodoroWorkPhase_pkgNotWhitelisted_returnsTrue() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed"),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isTrue()
    }

    @Test
    fun shouldBlock_expiresAtZero_returnsTrue() {
        // expiresAt = 0 ⇒ NOT in 1..now ⇒ blocking remains active (no expiry).
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 0L,
            whitelist = emptySet(),
        )
        assertThat(snap.shouldBlock("com.x", 1000L)).isTrue()
    }

    // -------- SEC-11: scadenza a doppio clock --------

    /// Snapshot con entrambi gli orologi (post-SEC-11).
    private fun dualClockSnapshot(expiresAtWall: Long, expiresAtElapsed: Long) =
        QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = expiresAtWall,
            whitelist = emptySet(),
            expiresAtElapsed = expiresAtElapsed,
        )

    @Test
    fun shouldBlock_forwardWallJumpAlone_doesNotEndFocusEarly() {
        // CUORE SEC-11: l'utente porta il WALL avanti oltre expiresAt per far
        // finire la sessione prima. Ma il monotonico (non falsificabile) non è
        // ancora scaduto → la sessione NON termina (fail-secure: non finire prima).
        val snap = dualClockSnapshot(expiresAtWall = 10_000L, expiresAtElapsed = 5_000L)
        // nowWall ben oltre la scadenza wall, nowElapsed ancora dentro.
        assertThat(snap.shouldBlock("com.x", nowWall = 999_999L, nowElapsed = 4_000L)).isTrue()
    }

    @Test
    fun shouldBlock_bothClocksPast_endsFocus() {
        // Tempo reale trascorso: ENTRAMBI gli orologi oltre la scadenza → scaduta.
        val snap = dualClockSnapshot(expiresAtWall = 10_000L, expiresAtElapsed = 5_000L)
        assertThat(snap.shouldBlock("com.x", nowWall = 11_000L, nowElapsed = 6_000L)).isFalse()
    }

    @Test
    fun shouldBlock_onlyElapsedPast_wallNotYet_staysBlocked() {
        // Solo il monotonico è oltre (es. wall spostato INDIETRO): l'AND richiede
        // anche il wall → non scaduta → resta bloccata (no fine anticipata; il
        // timer reale di QuickBlockManager azzera comunque lo snapshot a fine
        // durata, quindi nessuna estensione infinita reale).
        val snap = dualClockSnapshot(expiresAtWall = 10_000L, expiresAtElapsed = 5_000L)
        assertThat(snap.shouldBlock("com.x", nowWall = 1_000L, nowElapsed = 6_000L)).isTrue()
    }

    @Test
    fun shouldBlock_legacySnapshot_noElapsed_fallsBackToWallOnly() {
        // Snapshot legacy (expiresAtElapsed = 0): non potendo incrociare i clock,
        // comportamento wall-only storico → wall oltre ⇒ scaduta.
        val legacy = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = emptySet(),
            // expiresAtElapsed default 0
        )
        assertThat(legacy.shouldBlock("com.x", nowWall = 11_000L, nowElapsed = 1L)).isFalse()
        assertThat(legacy.shouldBlock("com.x", nowWall = 9_000L, nowElapsed = 999_999L)).isTrue()
    }

    @Test
    fun shouldBlock_dualClock_breakPhaseStillUnblocks() {
        // L'AND di scadenza non scavalca le altre regole: in break phase non si
        // blocca anche se non scaduto.
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = true,
            expiresAt = 10_000L,
            whitelist = emptySet(),
            expiresAtElapsed = 5_000L,
        )
        assertThat(snap.shouldBlock("com.x", nowWall = 1_000L, nowElapsed = 1_000L)).isFalse()
    }

    // -------- Snapshot.isSessionActiveNow (gate watch-all del :accessibility) --------

    @Test
    fun isSessionActiveNow_idle_false() {
        assertThat(QuickBlockStore.Snapshot.IDLE.isSessionActiveNow(1000L, 1000L)).isFalse()
    }

    @Test
    fun isSessionActiveNow_activeFutureExpiry_true() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = setOf("com.allowed"),
        )
        assertThat(snap.isSessionActiveNow(1000L, 1000L)).isTrue()
    }

    @Test
    fun isSessionActiveNow_activeExpired_false() {
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 500L,
            whitelist = emptySet(),
        )
        assertThat(snap.isSessionActiveNow(1000L, 1000L)).isFalse()
    }

    @Test
    fun isSessionActiveNow_breakPhase_true() {
        // REGRESSIONE: durante il break la sessione e' ancora ATTIVA → il
        // :accessibility deve continuare a osservare tutto (a differenza di
        // shouldBlock, che in break ritorna false). Cosi' al rientro in work
        // non serve ri-allargare il watched-set.
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = true,
            expiresAt = 10_000L,
            whitelist = emptySet(),
        )
        assertThat(snap.isSessionActiveNow(1000L, 1000L)).isTrue()
        // Coerenza col contratto: in break shouldBlock resta false.
        assertThat(snap.shouldBlock("com.x", 1000L)).isFalse()
    }

    @Test
    fun isSessionActiveNow_expiresAtZero_true() {
        // Nessuna scadenza impostata (expiresAt = 0) → sessione attiva.
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 0L,
            whitelist = emptySet(),
        )
        assertThat(snap.isSessionActiveNow(1000L, 1000L)).isTrue()
    }

    @Test
    fun isSessionActiveNow_forwardWallJumpAlone_staysActive() {
        // SEC-11: salto WALL in avanti da solo (monotonico non ancora scaduto)
        // non termina la sessione → resta attiva (mirror di shouldBlock).
        val snap = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = false,
            isBreakPhase = false,
            expiresAt = 10_000L,
            whitelist = emptySet(),
            expiresAtElapsed = 5_000L,
        )
        assertThat(snap.isSessionActiveNow(nowWall = 999_999L, nowElapsed = 4_000L)).isTrue()
    }

    // -------- save / read roundtrip --------

    @Test
    fun saveThenRead_exactRoundtrip_withWhitelist() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val original = QuickBlockStore.Snapshot(
            isActive = true,
            isPomodoroMode = true,
            isBreakPhase = false,
            expiresAt = 1_700_000_000_000L,
            whitelist = setOf("com.a", "com.b", "com.c"),
        )
        QuickBlockStore.save(ctx, original)
        val readBack = QuickBlockStore.read(ctx)

        assertThat(readBack.isActive).isTrue()
        assertThat(readBack.isPomodoroMode).isTrue()
        assertThat(readBack.isBreakPhase).isFalse()
        assertThat(readBack.expiresAt).isEqualTo(1_700_000_000_000L)
        assertThat(readBack.whitelist).containsExactly("com.a", "com.b", "com.c")
    }

    @Test
    fun saveIdle_thenRead_returnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        QuickBlockStore.save(ctx, QuickBlockStore.Snapshot.IDLE)
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }

    @Test
    fun saveThenRead_preservesExpiresAtElapsed() {
        // SEC-11: il clock monotonico deve sopravvivere alla serializzazione
        // (regression guard: un typo nella chiave sfuggirebbe ai test di
        // shouldBlock puri).
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        QuickBlockStore.save(
            ctx,
            QuickBlockStore.Snapshot(
                isActive = true,
                isPomodoroMode = false,
                isBreakPhase = false,
                expiresAt = 1_700_000_000_000L,
                whitelist = emptySet(),
                expiresAtElapsed = 987_654L,
            ),
        )
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack.expiresAt).isEqualTo(1_700_000_000_000L)
        assertThat(readBack.expiresAtElapsed).isEqualTo(987_654L)
    }

    @Test
    fun read_legacySnapshotWithoutElapsed_parsesElapsedAsZero() {
        // SEC-11 backward compat: uno snapshot scritto prima del campo
        // expiresAtElapsed deve parsare con elapsed = 0 (→ wall-only), senza
        // errori.
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText(
            """{"isActive":true,"isPomodoroMode":false,"isBreakPhase":false,"expiresAt":12345,"whitelist":["com.a"]}""",
        )
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack.isActive).isTrue()
        assertThat(readBack.expiresAt).isEqualTo(12345L)
        assertThat(readBack.expiresAtElapsed).isEqualTo(0L)
        assertThat(readBack.whitelist).containsExactly("com.a")
    }

    // -------- Fallback paths --------

    @Test
    fun read_corruptedFile_returnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, fileName).writeText("{not json")
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }

    @Test
    fun read_missingFile_returnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // Ensure file missing
        File(ctx.filesDir, fileName).delete()
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }

    // -------- clear --------

    @Test
    fun clear_writesIdle_andNextReadReturnsIdle() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        QuickBlockStore.save(
            ctx,
            QuickBlockStore.Snapshot(
                isActive = true,
                isPomodoroMode = false,
                isBreakPhase = false,
                expiresAt = 9999L,
                whitelist = setOf("com.x"),
            ),
        )
        QuickBlockStore.clear(ctx)
        val readBack = QuickBlockStore.read(ctx)
        assertThat(readBack).isEqualTo(QuickBlockStore.Snapshot.IDLE)
    }
}
