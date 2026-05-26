package com.dev.koru.channels

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * SEC-01 — truth table del predicato di autorizzazione
 * [StrictModeMethodChannel.clearsActiveBit].
 *
 * È la decisione di sicurezza centrale del gate native su `setStrictModeOptions`:
 * solo i cambi che SPENGONO un bit attivo (downgrade) richiedono il token
 * monouso; alzare la mask (aggiungere restrizioni) è libero. Bit dello strict
 * mode: EDITING=1, SETTINGS=2, UNINSTALLING=4, RECENT=8, SPLIT=16.
 */
class StrictModeAuthGateTest {

    @Test
    fun fullDisable_isDowngrade_requiresToken() {
        // 31 → 0: spegne tutti i bit (il bypass totale di SEC-01).
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 31, newMask = 0)).isTrue()
    }

    @Test
    fun clearingOneActiveBit_isDowngrade() {
        // 14 (SETTINGS|UNINSTALLING|RECENT) → 12 spegne SETTINGS(2).
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 14, newMask = 12)).isTrue()
    }

    @Test
    fun raisingMask_isNotDowngrade_noTokenNeeded() {
        // 0 → 31: aggiunge tutte le restrizioni → libero.
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 0, newMask = 31)).isFalse()
    }

    @Test
    fun addingOneBit_isNotDowngrade() {
        // 8 (RECENT) → 24 (RECENT|SPLIT): solo aggiunta → libero.
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 8, newMask = 24)).isFalse()
    }

    @Test
    fun noChange_isNotDowngrade() {
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 14, newMask = 14)).isFalse()
    }

    @Test
    fun fromZero_anyValue_isNeverDowngrade() {
        // Da mask 0 (strict mode spento) non c'è alcun bit attivo da proteggere.
        for (m in 0..31) {
            assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 0, newMask = m)).isFalse()
        }
    }

    @Test
    fun swap_clearOneAddAnother_isDowngrade() {
        // 2 (SETTINGS) → 4 (UNINSTALLING): spegne SETTINGS pur aggiungendo
        // UNINSTALLING → è comunque un downgrade (un bit attivo è stato tolto).
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 2, newMask = 4)).isTrue()
    }

    @Test
    fun supersetIsAllowed_subsetIsDowngrade() {
        // Proprietà generale: newMask superset di oldMask ⇒ no downgrade;
        // qualunque bit perso ⇒ downgrade.
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 5, newMask = 7)).isFalse() // 101→111
        assertThat(StrictModeMethodChannel.clearsActiveBit(oldMask = 7, newMask = 5)).isTrue() // 111→101
    }
}
