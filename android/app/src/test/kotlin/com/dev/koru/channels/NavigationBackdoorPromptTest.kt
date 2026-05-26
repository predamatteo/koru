package com.dev.koru.channels

import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * SEC-12 — test della parte cold-start di [NavigationMethodChannel].
 *
 * Quando KoruDeviceAdminReceiver.onDisableRequested lancia MainActivity a freddo
 * (FlutterEngine non ancora configurato), [NavigationMethodChannel.channel] è
 * null: [NavigationMethodChannel.goToBackdoorPrompt] non può fare push del
 * metodo, quindi marca la richiesta come PENDENTE. Il listener Dart la consuma
 * via `consumePendingBackdoorPrompt` appena registra l'handler.
 *
 * Qui verifichiamo l'invariante senza un FlutterEngine reale (non disponibile
 * sotto unit test): con channel null la richiesta diventa pendente; [resetForTest]
 * la azzera. Il push del warm path richiede un binaryMessenger reale ed è coperto
 * dal test Dart del navigation listener.
 */
class NavigationBackdoorPromptTest {

    @Before
    fun setUp() {
        // Il singleton `object` persiste tra i test nello stesso JVM.
        NavigationMethodChannel.resetForTest()
    }

    @After
    fun tearDown() {
        NavigationMethodChannel.resetForTest()
    }

    @Test
    fun freshState_noPendingPrompt() {
        assertThat(NavigationMethodChannel.isBackdoorPromptPendingForTest()).isFalse()
    }

    @Test
    fun goToBackdoorPrompt_coldStart_marksPending() {
        // channel == null (nessun register) → cold start: la richiesta deve
        // diventare pendente invece di andare persa.
        NavigationMethodChannel.goToBackdoorPrompt()
        assertThat(NavigationMethodChannel.isBackdoorPromptPendingForTest()).isTrue()
    }

    @Test
    fun resetForTest_clearsPending() {
        NavigationMethodChannel.goToBackdoorPrompt()
        assertThat(NavigationMethodChannel.isBackdoorPromptPendingForTest()).isTrue()
        NavigationMethodChannel.resetForTest()
        assertThat(NavigationMethodChannel.isBackdoorPromptPendingForTest()).isFalse()
    }

    @Test
    fun goToBackdoorPrompt_coldStart_idempotent() {
        // Più richieste a freddo restano una singola pendenza booleana.
        NavigationMethodChannel.goToBackdoorPrompt()
        NavigationMethodChannel.goToBackdoorPrompt()
        assertThat(NavigationMethodChannel.isBackdoorPromptPendingForTest()).isTrue()
    }
}
