package com.dev.koru.service

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import com.dev.koru.db.DbSchema
import com.dev.koru.db.NativeDatabase
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * CR-05 — Regression test su [LockForegroundService.triggerProfileReload].
 *
 * Il bug: triggerProfileReload (MAIN thread) chiamava NativeDatabase.close()
 * mentre LockRunnable iterava i cursori sul "BlockingThread" → IllegalState/
 * SQLiteException a metà iterazione, loadProfiles abortita, enforcement su dati
 * vuoti/parziali. Il fix: NON chiudere; settare solo `needsReload` e lasciare
 * che il worker ricarichi alla prossima tick (la connection resta aperta).
 *
 * Asseriamo le DUE proprietà del fix tramite i seam esistenti (companion field
 * `currentLockRunnable` via reflection):
 *  1. triggerProfileReload setta needsReload=true sul LockRunnable corrente
 *     (così il worker ricarica davvero → nessun enforcement gap).
 *  2. triggerProfileReload NON chiude la connection DB aperta (era la causa
 *     della race coi cursori del worker).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class TriggerProfileReloadTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()

    @Before
    fun setUp() {
        NativeDatabase.close()
        // findDbFile cerca koru.db in filesDir: crealo così open() riesce.
        val dbFile = File(ctx.filesDir, DbSchema.DB_NAME)
        if (dbFile.exists()) dbFile.delete()
        SQLiteDatabase.openOrCreateDatabase(dbFile, null).close()
    }

    @After
    fun tearDown() {
        setCurrentLockRunnable(null)
        NativeDatabase.close()
        File(ctx.filesDir, DbSchema.DB_NAME).delete()
    }

    @Test
    fun triggerProfileReload_setsNeedsReloadFlag() {
        val runnable = newLockRunnable()
        runnable.needsReload = false
        setCurrentLockRunnable(runnable)

        LockForegroundService.triggerProfileReload()

        assertThat(runnable.needsReload).isTrue()
    }

    @Test
    fun triggerProfileReload_doesNotCloseOpenDbConnection() {
        val runnable = newLockRunnable()
        setCurrentLockRunnable(runnable)

        // Apri la connection (come farebbe il worker prima di iterare i
        // cursori) e tienine il riferimento.
        val openDb = NativeDatabase.open(ctx)
        assertThat(openDb.isOpen).isTrue()

        LockForegroundService.triggerProfileReload()

        // Il fix CR-05: la connection NON deve essere stata chiusa sotto i
        // piedi del worker. Prima del fix questa era false (close() dal main
        // thread) e abortiva l'iterazione dei cursori.
        assertThat(openDb.isOpen).isTrue()
    }

    @Test
    fun triggerProfileReload_withNoRunnable_isNoOp() {
        // Difensivo: nessun LockRunnable attivo (service non avviato) → niente
        // NPE, niente close. La connection eventualmente aperta resta tale.
        setCurrentLockRunnable(null)
        val openDb = NativeDatabase.open(ctx)

        LockForegroundService.triggerProfileReload()

        assertThat(openDb.isOpen).isTrue()
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    /// LockRunnable reale con callback no-op: non lo avviamo (no Thread.start),
    /// ci serve solo come target del flag needsReload.
    private fun newLockRunnable(): LockRunnable = LockRunnable(
        context = ctx,
        onBlock = { _, _, _, _ -> },
        onLimitBlock = { _, _, _, _ -> },
        onUnblock = { },
        onFocusBlock = { _, _ -> },
    )

    private fun setCurrentLockRunnable(value: LockRunnable?) {
        // currentLockRunnable è un `@Volatile private` dichiarato nel companion
        // object di LockForegroundService. Kotlin compila i field dei companion
        // come field STATICI della classe ESTERNA (non della classe Companion),
        // quindi lo recuperiamo da LockForegroundService::class.java e lo
        // settiamo come static (obj = null).
        val f = LockForegroundService::class.java.getDeclaredField("currentLockRunnable")
        f.isAccessible = true
        f.set(null, value)
    }
}
