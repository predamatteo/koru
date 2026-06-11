package com.dev.koru.service

/// Rilevamento della schermata "recents" (task switcher) condiviso tra
/// [com.dev.koru.strictmode.StrictModeEnforcer] (bit BLOCK_RECENT_APPS) e
/// [LauncherRecentsGate] (blocco gesture scopato al launcher). Estratto per
/// tenere i due path allineati: prima i pattern vivevano inline nell'enforcer
/// e un secondo consumatore li avrebbe inevitabilmente fatti divergere.
///
/// Object PURO (nessuna dipendenza Android): testabile in JUnit senza
/// Robolectric.
object RecentsDetector {

    /// Pattern recents identici alla versione inline storica di
    /// StrictModeEnforcer (comportamento invariato). Check SOLO su className:
    /// il bare match sul package com.android.systemui triggerava sul
    /// pull-down della notification shade / QS panel (package systemui ma
    /// NON Recents). Copre: quickstep (com.android.quickstep.RecentsActivity,
    /// anche fallback.RecentsActivity), MIUI (com.miui.home.recents.*),
    /// Samsung/legacy systemui (*.recents.RecentsActivity), e i legacy OEM
    /// RecentTask / OverviewPanel.
    fun isRecentsWindow(packageName: String, className: String): Boolean {
        return className.contains("Recents", ignoreCase = true) ||
            className.contains("RecentTask", ignoreCase = true) ||
            className.contains("OverviewPanel", ignoreCase = true) ||
            (packageName.contains("launcher", ignoreCase = true) &&
                className.contains("Recent", ignoreCase = true))
    }

    /// Variante STRETTA per il gate del launcher: oltre al match className
    /// richiede che il package sia un plausibile host di recents (systemui o
    /// un launcher di sistema). Il gate è always-on quando il launcher Koru è
    /// in cima, quindi — a differenza dello strict mode, opt-in — non può
    /// permettersi falsi positivi su un'app terza qualsiasi che abbia
    /// "Recents" in un className. Le finestre di Koru stesso non matchano mai.
    fun isRecentsHostWindow(
        packageName: String,
        className: String,
        selfPackage: String,
        skipPackages: Set<String>,
    ): Boolean {
        if (packageName.isEmpty() || packageName == selfPackage) return false
        if (!isRecentsWindow(packageName, className)) return false
        return isPlausibleRecentsHostPackage(packageName, skipPackages)
    }

    /// Predicato UNICO per "questo package può ospitare la schermata recents"
    /// (systemui o un launcher). Condiviso da [isRecentsHostWindow], dal
    /// verify-before-kick e dal filtro click di LauncherRecentsGate: usare
    /// set diversi nei tre punti li fa divergere (es. il verify che
    /// classificava un host fuori da skipPackages come "app reale" e
    /// abortiva ogni kick).
    fun isPlausibleRecentsHostPackage(
        packageName: String,
        skipPackages: Set<String>,
    ): Boolean = packageName == "com.android.systemui" ||
        skipPackages.contains(packageName) ||
        packageName.contains("launcher", ignoreCase = true) ||
        packageName.contains("home", ignoreCase = true) ||
        packageName.contains("quickstep", ignoreCase = true)

    /// Match best-effort del bottone "Cancella tutto" dentro le recents.
    /// Primario: viewIdResourceName (locale-indipendente, es.
    /// "com.android.launcher:id/clear_all" — flagReportViewIds è attivo nel
    /// config del servizio). Fallback: testo del nodo nelle lingue note.
    /// Gli id OEM variano → quando non matcha, il reset resta disponibile
    /// via long-press sull'icona del launcher.
    fun isClearAllNode(viewIdResourceName: String?, text: CharSequence?): Boolean {
        val id = viewIdResourceName ?: ""
        if (id.contains("clear_all", ignoreCase = true) ||
            id.contains("clearAll", ignoreCase = true) ||
            // OxygenOS (net.oneplus.launcher): id osservato on-device =
            // "…:id/btn_clear" — senza questo match il rilevamento dipendeva
            // solo dal testo localizzato (fragile al cambio lingua).
            id.endsWith("/btn_clear", ignoreCase = true)
        ) {
            return true
        }
        val label = text?.toString()?.trim() ?: return false
        return label.equals("Clear all", ignoreCase = true) ||
            label.equals("Cancella tutto", ignoreCase = true) ||
            label.equals("Chiudi tutto", ignoreCase = true) ||
            label.equals("Close all", ignoreCase = true)
    }
}
