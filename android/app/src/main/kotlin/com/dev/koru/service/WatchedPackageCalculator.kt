package com.dev.koru.service

import com.dev.koru.db.NativeAppRelation

/**
 * Calcolo PURO del watched-set dell'AccessibilityService — l'insieme di package
 * per cui `serviceInfo.packageNames` chiede gli eventi finestra.
 *
 * ## Perche' esiste (enforcement gap)
 * `serviceInfo.packageNames` filtra QUALI app generano TYPE_WINDOW_STATE_CHANGED
 * verso il servizio. Un package fuori da questo set non viene mai valutato da
 * [KoruAccessibilityService.checkAppBlocking]: e' invisibile all'enforcement.
 *
 * Prima questo set conteneva SOLO le app dei profili abilitati (+ browser,
 * settings, skip, self). Ma i daily limit per-app ([AppUsageLimitsStore]) sono
 * GLOBALI e indipendenti dai profili: un'app con un cap di tempo ma non presente
 * in alcun profilo abilitato non veniva osservata, quindi il cap non scattava
 * mai (si "attivava" solo quando un profilo che la conteneva era abilitato).
 * Vedi [BlockPolicyEvaluator.evaluate] step 2 (daily limit), che e' gia'
 * profile-independent: il buco era a monte, nel filtro degli eventi.
 *
 * La DECISIONE — "quali package vanno osservati ORA?" — e' una funzione pura
 * dei suoi input. La estraggo qui per renderla unit-testabile (l'avversario e'
 * l'utente che cerca buchi di enforcement); il side-effect — leggere lo store
 * dei limiti e mutare `serviceInfo` — resta in
 * [KoruAccessibilityService.applyDynamicPackageFilter], che passa i risultati qui.
 */
object WatchedPackageCalculator {

    /**
     * L'unione dei package per cui il servizio deve ricevere eventi.
     *
     * @param profileApps relazioni app per profilo (gia' filtrate ai soli
     *   profili abilitati a monte, via `getEnabledProfiles`).
     * @param limitPackages package con un daily limit ATTIVO (minutes > 0),
     *   indipendenti dai profili — il fix di questo enforcement gap.
     * @param knownBrowsers / settingsPackages / skipPackages / selfPackage i
     *   set statici sempre osservati (browser per il website blocking, settings
     *   per lo strict mode, skip+self per ricevere l'evento di ritorno a HOME).
     */
    fun calculate(
        profileApps: Map<Int, List<NativeAppRelation>>,
        limitPackages: Set<String>,
        knownBrowsers: Set<String>,
        settingsPackages: Set<String>,
        skipPackages: Set<String>,
        selfPackage: String,
    ): Set<String> {
        val profilePackages = profileApps.values
            .flatten()
            .map { it.packageName }
            .toSet()
        return profilePackages + limitPackages + knownBrowsers +
            settingsPackages + skipPackages + selfPackage
    }
}
