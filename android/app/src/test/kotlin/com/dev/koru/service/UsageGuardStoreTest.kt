package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
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
 * SEC-03 — test di integrazione di [UsageGuardStore.observe] (persistenza
 * cross-process + accumulo). La logica di clock-tampering pura è coperta da
 * [UsageGuardDecideTest]; qui verifichiamo che lo store: inizializzi al raw,
 * accumuli col `max` entro lo stesso giorno (mai scendere), sopravviva a un
 * "altro processo" (cache azzerata = re-load da disco) e si resetti.
 *
 * `observe` usa il clock di sistema reale (now), quindi qui restiamo nello
 * STESSO giorno e stesso boot — niente salti temporali iniettabili (quelli
 * sono testati a livello di [UsageGuardStore.decide]).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class UsageGuardStoreTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()
    private val pkg = "com.instagram.android"
    private val fileName = "koru_usage_guard.json"

    @Before
    fun setUp() = resetState()

    @After
    fun tearDown() = resetState()

    @Test
    fun observe_firstCall_returnsRaw() {
        assertThat(UsageGuardStore.observe(ctx, pkg, 10 * 60_000L)).isEqualTo(10 * 60_000L)
    }

    @Test
    fun observe_accumulatesMax_neverDecreasesSameDay() {
        // Salita normale.
        assertThat(UsageGuardStore.observe(ctx, pkg, 10 * 60_000L)).isEqualTo(10 * 60_000L)
        assertThat(UsageGuardStore.observe(ctx, pkg, 25 * 60_000L)).isEqualTo(25 * 60_000L)
        // Raw che "scende" (glitch) → l'effettivo NON scende (max tenuto).
        assertThat(UsageGuardStore.observe(ctx, pkg, 5 * 60_000L)).isEqualTo(25 * 60_000L)
    }

    @Test
    fun observe_independentPerPackage() {
        UsageGuardStore.observe(ctx, "com.a", 30 * 60_000L)
        UsageGuardStore.observe(ctx, "com.b", 10 * 60_000L)
        // Un raw basso su com.a non scende; com.b indipendente.
        assertThat(UsageGuardStore.observe(ctx, "com.a", 0L)).isEqualTo(30 * 60_000L)
        assertThat(UsageGuardStore.observe(ctx, "com.b", 12 * 60_000L)).isEqualTo(12 * 60_000L)
    }

    @Test
    fun observe_persistsAcrossOtherProcess() {
        UsageGuardStore.observe(ctx, pkg, 40 * 60_000L)
        simulateOtherProcess()
        // Un secondo processo (cache vuota) deve leggere l'accumulato da disco:
        // un raw basso non lo abbassa.
        assertThat(UsageGuardStore.observe(ctx, pkg, 1 * 60_000L)).isEqualTo(40 * 60_000L)
    }

    @Test
    fun reset_clearsAccumulation() {
        UsageGuardStore.observe(ctx, pkg, 50 * 60_000L)
        UsageGuardStore.reset(ctx, pkg)
        // Dopo reset riparte dal raw corrente.
        assertThat(UsageGuardStore.observe(ctx, pkg, 3 * 60_000L)).isEqualTo(3 * 60_000L)
    }

    @Test
    fun observe_corruptFile_failsSafeReturnsRaw() {
        File(ctx.filesDir, fileName).writeText("{not json")
        cacheField().set(null)
        // File corrotto → readFresh riparte vuoto; primo osservo → raw.
        assertThat(UsageGuardStore.observe(ctx, pkg, 7 * 60_000L)).isEqualTo(7 * 60_000L)
    }

    // -------- helpers --------

    private fun resetState() {
        File(ctx.filesDir, fileName).delete()
        File(ctx.filesDir, "$fileName.tmp").delete()
        File(ctx.filesDir, "$fileName.lock").delete()
        cacheField().set(null)
    }

    private fun simulateOtherProcess() {
        cacheField().set(null)
    }

    private fun cacheField(): AtomicReference<Any?> {
        val f = UsageGuardStore::class.java.getDeclaredField("cache")
        f.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        return f.get(UsageGuardStore) as AtomicReference<Any?>
    }
}
