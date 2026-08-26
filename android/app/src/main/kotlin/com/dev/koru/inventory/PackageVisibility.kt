package com.dev.koru.inventory

/**
 * Predicato **puro** "questo package è un'app che conta per l'utente?".
 *
 * Nessuna dipendenza Android, quindi testabile in JVM senza Robolectric —
 * stesso stampo di [com.dev.koru.service.WatchedPackageCalculator] e di
 * [com.dev.koru.service.OpenAppsTracker.shouldTrack], da cui questo è la
 * generalizzazione.
 *
 * ## Perché esiste
 *
 * La stessa domanda veniva risposta in quattro posti diversi con criteri
 * diversi: [com.dev.koru.channels.blocking.AppInventoryCallHandler] (drawer,
 * CATEGORY_LAUNCHER), `UsageWidgetDataSource` (widget, CATEGORY_LAUNCHER +
 * denylist `SKIP_PACKAGES`), `OpenAppsTracker` (contatore schede) e il lato
 * Dart (`visibleAppsProvider`, CATEGORY_HOME). Le statistiche invece non
 * filtravano affatto: `com.android.systemui`, `android` e Koru stessa
 * arrivavano fino allo schermo, e Koru — essendo il launcher di default —
 * dominava stabilmente la classifica di utilizzo.
 *
 * ## Il criterio
 *
 * Un package è "user facing" se:
 * 1. è **apribile** — dichiara un'activity MAIN + CATEGORY_LAUNCHER, cioè ha
 *    un'icona nel drawer. Esclude IME, componenti Play (SafetyCore, Key
 *    Verifier), servizi di background;
 * 2. **non è un launcher** — non dichiara CATEGORY_HOME. Il criterio è
 *    dinamico apposta: la denylist `SKIP_PACKAGES` copre i ~14 launcher OEM
 *    noti ma non Nova, Lawnchair o Niagara, che sono launchable e comparivano
 *    quindi nelle statistiche e nel widget;
 * 3. **non è nella skip-list** di framework/systemui;
 * 4. **non è Koru stessa**, salvo che il chiamante chieda diversamente
 *    ([keepSelf]).
 *
 * NOTA — "app di sistema" NON significa `FLAG_SYSTEM`. Su un Pixel, YouTube,
 * Chrome, Gmail, Foto e Play Store sono preinstallate e portano quel flag:
 * filtrare su di esso nasconderebbe esattamente le app che l'utente vuole
 * vedere e limitare. Il criterio è "apribile e non launcher", non "non di
 * sistema".
 *
 * ## Fail-open, sempre
 *
 * [launchablePackages] vuoto significa "la query al PackageManager è fallita",
 * non "questo device non ha app apribili" (impossibile su hardware reale). In
 * quel caso il filtro launchable si spegne invece di svuotare liste e
 * statistiche. Stessa postura difensiva del `filterActive` di
 * `TodayLimitsCard` e del filtro launchable del widget.
 */
object PackageVisibility {

    /**
     * @param keepSelf `true` solo per il drawer: Koru resta apribile da lì per
     *   chi ha cambiato launcher di default. In statistiche e picker va
     *   esclusa — come launcher predefinito monopolizzerebbe la classifica, e
     *   proporre di bloccare Koru con Koru non ha senso.
     */
    fun isUserFacing(
        pkg: String,
        selfPackage: String,
        launchablePackages: Set<String>,
        homePackages: Set<String>,
        skipPackages: Set<String>,
        keepSelf: Boolean = false,
    ): Boolean {
        if (pkg.isEmpty()) return false
        if (pkg == selfPackage) return keepSelf
        if (skipPackages.contains(pkg)) return false
        if (homePackages.contains(pkg)) return false
        // Fail-open: vedi nota di classe.
        if (launchablePackages.isNotEmpty() && !launchablePackages.contains(pkg)) {
            return false
        }
        return true
    }

    /// Variante su mappa `package → valore`, per filtrare in un colpo solo le
    /// mappe di utilizzo che arrivano da `UsageCounter`. L'ordine di iterazione
    /// della mappa in ingresso è preservato.
    fun <T> filterUserFacing(
        usage: Map<String, T>,
        selfPackage: String,
        launchablePackages: Set<String>,
        homePackages: Set<String>,
        skipPackages: Set<String>,
        keepSelf: Boolean = false,
    ): Map<String, T> = usage.filterKeys { pkg ->
        isUserFacing(
            pkg = pkg,
            selfPackage = selfPackage,
            launchablePackages = launchablePackages,
            homePackages = homePackages,
            skipPackages = skipPackages,
            keepSelf = keepSelf,
        )
    }
}
