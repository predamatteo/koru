package com.dev.koru.strictmode

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * SEC-02 — truth table della decisione [StrictModeFailSafe.shouldReassert].
 *
 * Ri-armiamo lo strict (fail-secure) SSE il device admin è ancora attivo
 * (segnale durevole che sopravvive a Clear Data ⇒ "strict era armato") MA lo
 * store cifrato è vergine (mask mai scritta ⇒ i dati sono stati cancellati,
 * non un disable legittimo, che scriverebbe `mask=0`).
 */
class StrictModeFailSafeTest {

    @Test
    fun adminActiveAndStoreFresh_isTampering_reasserts() {
        // Firma del Clear Data con strict armato.
        assertThat(StrictModeFailSafe.shouldReassert(deviceAdminActive = true, storeFresh = true))
            .isTrue()
    }

    @Test
    fun adminActiveButStoreHasMask_legitDisable_doesNotReassert() {
        // Disable legittimo: saveMask(0) ha scritto la chiave → store non
        // vergine → niente re-arm (no falso positivo).
        assertThat(StrictModeFailSafe.shouldReassert(deviceAdminActive = true, storeFresh = false))
            .isFalse()
    }

    @Test
    fun freshInstall_noAdmin_doesNotReassert() {
        // Prima installazione pulita: nessun device admin → niente re-arm.
        assertThat(StrictModeFailSafe.shouldReassert(deviceAdminActive = false, storeFresh = true))
            .isFalse()
    }

    @Test
    fun noAdminWithStoredMask_doesNotReassert() {
        assertThat(StrictModeFailSafe.shouldReassert(deviceAdminActive = false, storeFresh = false))
            .isFalse()
    }
}
