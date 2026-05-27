package com.dev.koru.contract

/**
 * ARCH-06 — Single source of truth per i "magic number" del blocking che PRIMA
 * erano duplicati a mano in più file, tenuti allineati solo da commenti
 * "DEVONO matchare" (rischio di divergenza silenziosa: cambi un valore in un
 * file e dimentichi l'altro → enforcement incoerente fra i path).
 *
 * Questo oggetto dichiara UNA VOLTA SOLA:
 *  - i bit della mask Strict Mode ([BLOCK_EDITING] … [BLOCK_SPLIT_SCREEN]) +
 *    il valore aggregato fail-secure [ALL_OPTIONS_ENABLED];
 *  - il set di package "settings" ([SETTINGS_PACKAGES]) usato sia da
 *    `StrictModeEnforcer` per il blocco sia da `KoruAccessibilityService` per
 *    popolare `serviceInfo.packageNames`;
 *  - i codici `restrictionType` scritti su `restricted_access_events`
 *    ([RESTRICTION_TYPE_APP] … [RESTRICTION_TYPE_BYPASS_EXPIRED]).
 *
 * VINCOLI DI VALORE (non modificabili senza una migrazione esplicita):
 *  - I bit Strict Mode sono persistiti nella mask cifrata
 *    (`StrictModeStore`) e letti dal canale Flutter: cambiare un valore
 *    invaliderebbe le mask salvate sui device esistenti.
 *  - I codici `restrictionType` sono scritti in chiaro nella colonna
 *    `restriction_type` del DB e letti dalle statistiche Dart: cambiarli
 *    ri-etichetterebbe lo storico.
 *  - [ALL_OPTIONS_ENABLED] è tenuto come LETTERALE (`31`) e non come
 *    `BLOCK_EDITING or … or BLOCK_SPLIT_SCREEN` perché serve in contesti
 *    `const val` (es. `StrictModeStore.ALL_OPTIONS_ENABLED`) dove l'operatore
 *    `or` non è una compile-time constant in Kotlin. Il test
 *    [com.dev.koru.contract.BlockingContractTest] verifica comunque che
 *    `31 == (1|2|4|8|16)` così la coerenza è garantita a test-time.
 *
 * I file che prima duplicavano questi valori ora li referenziano (direttamente
 * o tramite un sottile alias `const val X = BlockingContract.X` mantenuto per
 * non rompere i call site esterni — vedi `StrictModeStore`/`StrictModeEnforcer`).
 */
object BlockingContract {

    // ─── Strict Mode: bit della mask ────────────────────────────────────────
    // Valori persistiti nella mask cifrata e letti dal canale Flutter.

    const val BLOCK_EDITING = 1
    const val BLOCK_SETTINGS = 2
    const val BLOCK_UNINSTALLING = 4
    const val BLOCK_RECENT_APPS = 8
    const val BLOCK_SPLIT_SCREEN = 16

    /// Tutti i 5 bit MVP attivi (1|2|4|8|16 = 31). Valore fail-secure: usato
    /// quando lo store della mask è tamper-ato o irrecuperabile. NON è 0 — un
    /// attaccante che resetta lo store deve trovarsi con TUTTO bloccato, non con
    /// tutto sbloccato. Letterale (non `or` dei bit) per poter restare
    /// `const val` nei call site; il test verifica `31 == 1|2|4|8|16`.
    const val ALL_OPTIONS_ENABLED: Int = 31

    // ─── Strict Mode: package "settings" (system + OEM) ──────────────────────
    // Condiviso fra StrictModeEnforcer (blocco) e KoruAccessibilityService
    // (popolamento di serviceInfo.packageNames). Era duplicato a mano nei due.

    val SETTINGS_PACKAGES: Set<String> = setOf(
        "com.android.settings",
        "com.samsung.android.app.routines",
        "com.miui.securitycenter",
        "com.coloros.safecenter",
        "com.coloros.oplusphonemanager",
        "com.huawei.systemmanager",
        "com.oneplus.security",
        "com.oplus.settings",
    )

    // ─── restricted_access_events: codici restrictionType ────────────────────
    // Scritti in chiaro nella colonna `restriction_type` e letti dalle stats
    // Dart. Erano passati come literal grezzi a ogni insertRestrictedAccessEvent.

    const val RESTRICTION_TYPE_APP = 0
    const val RESTRICTION_TYPE_SECTION = 1
    const val RESTRICTION_TYPE_WEBSITE = 2
    const val RESTRICTION_TYPE_USAGE_LIMIT = 3
    const val RESTRICTION_TYPE_FOCUS_MODE = 4
    const val RESTRICTION_TYPE_BYPASS_EXPIRED = 5
}
