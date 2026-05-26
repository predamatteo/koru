package com.dev.koru.service

import android.content.Context
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import com.dev.koru.overlay.BlockReason
import com.google.common.truth.Truth.assertThat
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests per [BypassStore] — la persistenza cross-process introdotta dal fix M2
 * e l'hardening anti-clock-manipulation di [BypassEntry.isActive].
 *
 * Coprono round-trip della serializzazione (a due orologi), il fail-safe di
 * parsing del `reason`, lo skip di `untilWall<=0`, la proprietà CENTRALE di M2
 * ("scritto da un processo, letto da un altro" — simulato azzerando la cache
 * statica), e la logica di scadenza a doppio clock (wall + monotonico).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class BypassStoreTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()
    private val pkg = "com.instagram.android"
    private val fileName = "koru_bypasses.json"

    @Before
    fun setUp() {
        resetState()
    }

    @After
    fun tearDown() {
        resetState()
    }

    // -------- persistenza / serializzazione --------

    @Test
    fun put_isReadableByOtherProcess() {
        val durationMs = 5 * 60_000L
        val expectedWall = System.currentTimeMillis() + durationMs
        BypassStore.put(ctx, pkg, activeEntry(BlockReason.USAGE_LIMIT, durationMs))
        simulateOtherProcess()
        val entry = BypassStore.read(ctx)[pkg]
        assertThat(entry).isNotNull()
        assertThat(entry!!.reason).isEqualTo(BlockReason.USAGE_LIMIT)
        // until persistito (tolleranza per il tempo trascorso nel test).
        assertThat(entry.untilWall).isAtLeast(expectedWall - 5_000L)
        assertThat(entry.isActive()).isTrue()
    }

    @Test
    fun reason_roundTripsForEveryValue() {
        for (reason in BlockReason.values()) {
            BypassStore.put(ctx, pkg, activeEntry(reason))
            simulateOtherProcess()
            assertThat(BypassStore.read(ctx)[pkg]?.reason).isEqualTo(reason)
        }
    }

    @Test
    fun unknownReason_parsesToAppBlocked_failSafe() {
        // File forgiato/corrotto con reason sconosciuto ⇒ APP_BLOCKED (NON
        // USAGE_LIMIT), così non sospende il cap giornaliero.
        val wall = System.currentTimeMillis() + 60_000L
        val elapsed = SystemClock.elapsedRealtime() + 60_000L
        writeRawFile("""{"$pkg":{"untilWall":$wall,"untilElapsed":$elapsed,"reason":"GARBAGE_REASON"}}""")
        assertThat(BypassStore.read(ctx)[pkg]?.reason).isEqualTo(BlockReason.APP_BLOCKED)
    }

    @Test
    fun missingReason_parsesToAppBlocked_failSafe() {
        val wall = System.currentTimeMillis() + 60_000L
        val elapsed = SystemClock.elapsedRealtime() + 60_000L
        writeRawFile("""{"$pkg":{"untilWall":$wall,"untilElapsed":$elapsed}}""")
        assertThat(BypassStore.read(ctx)[pkg]?.reason).isEqualTo(BlockReason.APP_BLOCKED)
    }

    @Test
    fun nonPositiveUntilWall_isSkippedOnRead() {
        writeRawFile(
            """{"$pkg":{"untilWall":0,"untilElapsed":1,"reason":"USAGE_LIMIT"},""" +
                """"other.pkg":{"untilWall":-5,"untilElapsed":1,"reason":"USAGE_LIMIT"}}""",
        )
        assertThat(BypassStore.read(ctx)).isEmpty()
    }

    @Test
    fun removePackage_clearsAppWideAndPerDomain_visibleCrossProcess() {
        BypassStore.put(ctx, pkg, activeEntry(BlockReason.APP_BLOCKED))
        BypassStore.put(ctx, "$pkg|reddit.com", activeEntry(BlockReason.WEBSITE_BLOCKED))
        BypassStore.put(ctx, "other.pkg", activeEntry(BlockReason.APP_BLOCKED))
        BypassStore.removePackage(ctx, pkg)
        simulateOtherProcess()
        // Rimosse la app-wide e la per-dominio di pkg; l'altra app resta.
        assertThat(BypassStore.read(ctx).keys).containsExactly("other.pkg")
    }

    @Test
    fun put_prunesOtherInactiveEntries() {
        // Una entry scaduta (wall passato) resta su disco finché un put non la
        // pota: verifichiamo che il prossimo put la elimini.
        val pastWall = System.currentTimeMillis() - 1_000L
        val pastElapsed = SystemClock.elapsedRealtime() - 1_000L
        writeRawFile("""{"stale.pkg":{"untilWall":$pastWall,"untilElapsed":$pastElapsed,"reason":"USAGE_LIMIT"}}""")
        BypassStore.put(ctx, pkg, activeEntry(BlockReason.USAGE_LIMIT))
        simulateOtherProcess()
        assertThat(BypassStore.read(ctx).keys).containsExactly(pkg)
    }

    @Test
    fun clearAll_emptiesStore_visibleCrossProcess() {
        BypassStore.put(ctx, pkg, activeEntry(BlockReason.USAGE_LIMIT))
        BypassStore.clearAll(ctx)
        simulateOtherProcess()
        assertThat(BypassStore.read(ctx)).isEmpty()
    }

    // -------- doppio clock (anti clock-manipulation) --------

    @Test
    fun isActive_normalWindow_true() {
        val e = BypassEntry(untilWall = 10_500, untilElapsed = 5_500, reason = BlockReason.USAGE_LIMIT)
        // 1s dentro la finestra su entrambi gli orologi.
        assertThat(e.isActive(nowWall = 9_600, nowElapsed = 4_600)).isTrue()
    }

    @Test
    fun isActive_clockMovedBack_doesNotExtend() {
        // untilWall=10_500, untilElapsed=5_500. L'utente sposta il wall MOLTO
        // indietro (nowWall=1_000, ben dentro), ma il tempo REALE è trascorso
        // oltre la durata (nowElapsed=6_000 > untilElapsed) → NON attivo.
        val e = BypassEntry(untilWall = 10_500, untilElapsed = 5_500, reason = BlockReason.USAGE_LIMIT)
        assertThat(e.isActive(nowWall = 1_000, nowElapsed = 6_000)).isFalse()
    }

    @Test
    fun isActive_rebootElapsedReset_failsClosed() {
        // Dopo un reboot elapsedRealtime riparte da ~0 (nowElapsed piccolo <
        // untilElapsed grande → "attivo" sul monotonico), MA il wall è
        // trascorso oltre untilWall → l'AND lo rende NON attivo (fail-closed).
        val e = BypassEntry(untilWall = 10_500, untilElapsed = 900_000, reason = BlockReason.USAGE_LIMIT)
        assertThat(e.isActive(nowWall = 11_000, nowElapsed = 50)).isFalse()
    }

    // -------- helpers --------

    private fun activeEntry(reason: BlockReason, durationMs: Long = 60_000L) =
        BypassEntry(
            untilWall = System.currentTimeMillis() + durationMs,
            untilElapsed = SystemClock.elapsedRealtime() + durationMs,
            reason = reason,
        )

    private fun resetState() {
        File(ctx.filesDir, fileName).delete()
        cacheField().set(null)
    }

    /// Azzera la cache statica → la prossima read ricarica da disco, come un
    /// secondo processo che non ha ancora popolato la propria cache.
    private fun simulateOtherProcess() {
        cacheField().set(null)
    }

    /// Scrive un file grezzo (per simulare contenuti forgiati/corrotti) e
    /// invalida la cache così la read successiva ricarica da disco.
    private fun writeRawFile(content: String) {
        File(ctx.filesDir, fileName).writeText(content)
        cacheField().set(null)
    }

    private fun cacheField(): AtomicReference<Any?> {
        val f = BypassStore::class.java.getDeclaredField("cache")
        f.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        return f.get(BypassStore) as AtomicReference<Any?>
    }
}
