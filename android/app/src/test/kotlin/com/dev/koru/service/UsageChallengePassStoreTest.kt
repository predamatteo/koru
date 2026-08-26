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

/**
 * Le tre proprietà che rendono il lasciapassare un gate e non una formalità:
 * è legato al package, scade, e si brucia all'uso. Se una qualsiasi salta, la
 * sfida diventa un fastidio da fare una volta al giorno invece del prezzo di
 * ogni singolo "Open anyway".
 */
@RunWith(RobolectricTestRunner::class)
class UsageChallengePassStoreTest {

    private val fileName = "koru_usage_challenge_pass.json"
    private val context: Context
        get() = ApplicationProvider.getApplicationContext()

    @Before
    fun setUp() = clean()

    @After
    fun tearDown() = clean()

    private fun clean() {
        File(context.filesDir, fileName).delete()
        UsageChallengePassStore.invalidateCacheForTest()
    }

    @Test
    fun noPassByDefault() {
        assertThat(UsageChallengePassStore.isValid(context, "com.x")).isFalse()
    }

    @Test
    fun grantMakesThePassValid() {
        UsageChallengePassStore.grant(context, "com.x")
        assertThat(UsageChallengePassStore.isValid(context, "com.x")).isTrue()
    }

    @Test
    fun passIsBoundToItsPackage() {
        // Superare la sfida per Instagram non deve aprire YouTube.
        UsageChallengePassStore.grant(context, "com.instagram.android")
        assertThat(
            UsageChallengePassStore.isValid(context, "com.google.android.youtube"),
        ).isFalse()
    }

    @Test
    fun passExpires() {
        val now = 1_000_000L
        UsageChallengePassStore.grant(context, "com.x", nowMs = now)
        assertThat(
            UsageChallengePassStore.isValid(
                context,
                "com.x",
                nowMs = now + UsageChallengePassStore.TTL_MS + 1,
            ),
        ).isFalse()
    }

    @Test
    fun passIsStillValidJustBeforeExpiry() {
        val now = 1_000_000L
        UsageChallengePassStore.grant(context, "com.x", nowMs = now)
        assertThat(
            UsageChallengePassStore.isValid(
                context,
                "com.x",
                nowMs = now + UsageChallengePassStore.TTL_MS - 1,
            ),
        ).isTrue()
    }

    @Test
    fun consumeBurnsThePass() {
        // È ciò che rende il gate RIPETIBILE: senza, la prima sfida della
        // giornata pagherebbe per ogni bypass successivo entro il TTL.
        UsageChallengePassStore.grant(context, "com.x")
        UsageChallengePassStore.consume(context, "com.x")
        assertThat(UsageChallengePassStore.isValid(context, "com.x")).isFalse()
    }

    @Test
    fun consumeOnAnUnknownPackageIsANoOp() {
        UsageChallengePassStore.grant(context, "com.x")
        UsageChallengePassStore.consume(context, "com.other")
        assertThat(UsageChallengePassStore.isValid(context, "com.x")).isTrue()
    }

    @Test
    fun passSurvivesAProcessRestart() {
        // Deve arrivare al DISCO: l'overlay lo legge da un altro punto del
        // ciclo di vita rispetto a chi lo ha scritto.
        UsageChallengePassStore.grant(context, "com.x")
        UsageChallengePassStore.invalidateCacheForTest()
        assertThat(UsageChallengePassStore.isValid(context, "com.x")).isTrue()
    }

    @Test
    fun corruptFileFailsSecure() {
        // All'opposto di AppUsageLimitsStore: là il fail-safe è "il limite
        // resta", qui è "il permesso non c'è". Corrompere il file non deve
        // essere un modo per farsi autorizzare.
        File(context.filesDir, fileName).writeText("{ this is not json")
        UsageChallengePassStore.invalidateCacheForTest()
        assertThat(UsageChallengePassStore.isValid(context, "com.x")).isFalse()
    }

    @Test
    fun grantingASecondPackageKeepsTheFirst() {
        UsageChallengePassStore.grant(context, "com.a")
        UsageChallengePassStore.grant(context, "com.b")
        assertThat(UsageChallengePassStore.isValid(context, "com.a")).isTrue()
        assertThat(UsageChallengePassStore.isValid(context, "com.b")).isTrue()
    }
}
