package com.dev.koru.contract

import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.strictmode.StrictModeEnforcer
import com.dev.koru.strictmode.StrictModeStore
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * ARCH-06 — Guardia del contratto dei "magic number" del blocking.
 *
 * [BlockingContract] è la single source dei valori che PRIMA erano duplicati a
 * mano (bit Strict Mode, SETTINGS_PACKAGES, codici restrictionType). Questo
 * test blinda due cose:
 *  1. i VALORI esatti che il resto del codice e il DB/Flutter si aspettano
 *     (un cambio accidentale ri-etichetterebbe lo storico o invaliderebbe le
 *     mask salvate) — vedi i vincoli documentati in [BlockingContract];
 *  2. che gli ALIAS pubblici lasciati per backward-compat
 *     (`StrictModeEnforcer.*`, `StrictModeStore.*`,
 *     `KoruAccessibilityService.*`) puntino davvero al contratto: se qualcuno
 *     ne scollegasse uno reintroducendo un literal, questo test fallisce.
 *
 * Niente Robolectric: sono tutte costanti / set in-JVM.
 */
class BlockingContractTest {

    // ─── Valori esatti (anti-regressione sui literal contrattuali) ───────────

    @Test
    fun strictModeBits_haveExpectedValues() {
        assertThat(BlockingContract.BLOCK_EDITING).isEqualTo(1)
        assertThat(BlockingContract.BLOCK_SETTINGS).isEqualTo(2)
        assertThat(BlockingContract.BLOCK_UNINSTALLING).isEqualTo(4)
        assertThat(BlockingContract.BLOCK_RECENT_APPS).isEqualTo(8)
        assertThat(BlockingContract.BLOCK_SPLIT_SCREEN).isEqualTo(16)
    }

    @Test
    fun allOptionsEnabled_isOrOfAllBits_andLiteral31() {
        // ALL_OPTIONS_ENABLED è tenuto come letterale `31` (serve in `const val`)
        // ma DEVE coincidere con l'OR di tutti i bit. Questo è esattamente il
        // controllo che il letterale hardcoded non possa divergere dai bit.
        val orOfBits = BlockingContract.BLOCK_EDITING or
            BlockingContract.BLOCK_SETTINGS or
            BlockingContract.BLOCK_UNINSTALLING or
            BlockingContract.BLOCK_RECENT_APPS or
            BlockingContract.BLOCK_SPLIT_SCREEN
        assertThat(BlockingContract.ALL_OPTIONS_ENABLED).isEqualTo(31)
        assertThat(BlockingContract.ALL_OPTIONS_ENABLED).isEqualTo(orOfBits)
    }

    @Test
    fun restrictionTypes_haveExpectedDbCodes() {
        // Questi Int sono scritti in chiaro nella colonna `restriction_type` e
        // letti dalle statistiche Dart: i valori sono parte del contratto dati.
        assertThat(BlockingContract.RESTRICTION_TYPE_APP).isEqualTo(0)
        assertThat(BlockingContract.RESTRICTION_TYPE_SECTION).isEqualTo(1)
        assertThat(BlockingContract.RESTRICTION_TYPE_WEBSITE).isEqualTo(2)
        assertThat(BlockingContract.RESTRICTION_TYPE_USAGE_LIMIT).isEqualTo(3)
        assertThat(BlockingContract.RESTRICTION_TYPE_FOCUS_MODE).isEqualTo(4)
        assertThat(BlockingContract.RESTRICTION_TYPE_BYPASS_EXPIRED).isEqualTo(5)
    }

    @Test
    fun restrictionTypeCodes_areDistinct() {
        val codes = listOf(
            BlockingContract.RESTRICTION_TYPE_APP,
            BlockingContract.RESTRICTION_TYPE_SECTION,
            BlockingContract.RESTRICTION_TYPE_WEBSITE,
            BlockingContract.RESTRICTION_TYPE_USAGE_LIMIT,
            BlockingContract.RESTRICTION_TYPE_FOCUS_MODE,
            BlockingContract.RESTRICTION_TYPE_BYPASS_EXPIRED,
        )
        assertThat(codes).containsNoDuplicates()
    }

    @Test
    fun settingsPackages_matchExpectedSet() {
        assertThat(BlockingContract.SETTINGS_PACKAGES).containsExactly(
            "com.android.settings",
            "com.samsung.android.app.routines",
            "com.miui.securitycenter",
            "com.coloros.safecenter",
            "com.coloros.oplusphonemanager",
            "com.huawei.systemmanager",
            "com.oneplus.security",
            "com.oplus.settings",
        )
    }

    // ─── Gli alias di backward-compat puntano al contratto ───────────────────

    @Test
    fun strictModeEnforcerBits_aliasContract() {
        assertThat(StrictModeEnforcer.BLOCK_EDITING).isEqualTo(BlockingContract.BLOCK_EDITING)
        assertThat(StrictModeEnforcer.BLOCK_SETTINGS).isEqualTo(BlockingContract.BLOCK_SETTINGS)
        assertThat(StrictModeEnforcer.BLOCK_UNINSTALLING).isEqualTo(BlockingContract.BLOCK_UNINSTALLING)
        assertThat(StrictModeEnforcer.BLOCK_RECENT_APPS).isEqualTo(BlockingContract.BLOCK_RECENT_APPS)
        assertThat(StrictModeEnforcer.BLOCK_SPLIT_SCREEN).isEqualTo(BlockingContract.BLOCK_SPLIT_SCREEN)
    }

    @Test
    fun strictModeStoreBits_aliasContract() {
        assertThat(StrictModeStore.BLOCK_EDITING).isEqualTo(BlockingContract.BLOCK_EDITING)
        assertThat(StrictModeStore.BLOCK_SETTINGS).isEqualTo(BlockingContract.BLOCK_SETTINGS)
        assertThat(StrictModeStore.BLOCK_UNINSTALLING).isEqualTo(BlockingContract.BLOCK_UNINSTALLING)
        assertThat(StrictModeStore.BLOCK_RECENT_APPS).isEqualTo(BlockingContract.BLOCK_RECENT_APPS)
        assertThat(StrictModeStore.BLOCK_SPLIT_SCREEN).isEqualTo(BlockingContract.BLOCK_SPLIT_SCREEN)
    }

    @Test
    fun strictModeStoreAllOptions_aliasesContract() {
        assertThat(StrictModeStore.ALL_OPTIONS_ENABLED)
            .isEqualTo(BlockingContract.ALL_OPTIONS_ENABLED)
    }

    @Test
    fun serviceSettingsPackages_areTheContractSet() {
        // KoruAccessibilityService.SETTINGS_PACKAGES popola serviceInfo.packageNames
        // e DEVE essere lo stesso set che lo StrictModeEnforcer usa per bloccare.
        assertThat(KoruAccessibilityService.SETTINGS_PACKAGES)
            .isEqualTo(BlockingContract.SETTINGS_PACKAGES)
    }

    @Test
    fun serviceBypassExpiredConst_aliasesContract() {
        assertThat(KoruAccessibilityService.RESTRICTION_TYPE_BYPASS_EXPIRED)
            .isEqualTo(BlockingContract.RESTRICTION_TYPE_BYPASS_EXPIRED)
    }
}
