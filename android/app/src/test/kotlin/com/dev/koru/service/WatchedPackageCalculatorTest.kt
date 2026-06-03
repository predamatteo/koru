package com.dev.koru.service

import com.dev.koru.db.NativeAppRelation
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [WatchedPackageCalculator.calculate]. Avversario: l'utente che
 * cerca buchi di enforcement. Proprieta' chiave (regressione del bug "il cap si
 * attiva solo a profilo abilitato"): un package con un daily limit attivo deve
 * essere osservato ANCHE quando non e' in alcun profilo abilitato.
 */
class WatchedPackageCalculatorTest {

    private val IG = "com.instagram.android"
    private val WA = "com.whatsapp"
    private val BROWSER = "com.android.chrome"
    private val SETTINGS = "com.android.settings"
    private val SYSTEMUI = "com.android.systemui"
    private val SELF = "com.dev.koru"

    private val browsers = setOf(BROWSER)
    private val settings = setOf(SETTINGS)
    private val skip = setOf(SYSTEMUI)

    private fun relation(pkg: String, profileId: Int = 1) = NativeAppRelation(
        packageName = pkg,
        profileId = profileId,
        isEnabled = true,
        overlayConfigJson = null,
        blockedSectionsJson = null,
    )

    private fun calc(
        profileApps: Map<Int, List<NativeAppRelation>> = emptyMap(),
        limitPackages: Set<String> = emptySet(),
    ) = WatchedPackageCalculator.calculate(
        profileApps = profileApps,
        limitPackages = limitPackages,
        knownBrowsers = browsers,
        settingsPackages = settings,
        skipPackages = skip,
        selfPackage = SELF,
    )

    @Test
    fun includesProfileApps() {
        val watched = calc(profileApps = mapOf(1 to listOf(relation(WA))))
        assertThat(watched).contains(WA)
    }

    @Test
    fun includesLimitPackageWithoutAnyProfile_regression() {
        // Il caso del bug: IG ha un cap ma NON e' in alcun profilo (abilitato).
        // Deve comunque essere osservato, altrimenti il cap non scatta mai.
        val watched = calc(profileApps = emptyMap(), limitPackages = setOf(IG))
        assertThat(watched).contains(IG)
    }

    @Test
    fun limitPackageStaysWatchedEvenIfItsProfileIsAbsent() {
        // IG ha un cap; nello snapshot c'e' solo il profilo di WA (quello di IG
        // e' stato disabilitato → assente da profileApps). IG resta osservato.
        val watched = calc(
            profileApps = mapOf(1 to listOf(relation(WA))),
            limitPackages = setOf(IG),
        )
        assertThat(watched).containsAtLeast(WA, IG)
    }

    @Test
    fun alwaysIncludesStaticSets() {
        val watched = calc()
        assertThat(watched).containsAtLeast(BROWSER, SETTINGS, SYSTEMUI, SELF)
    }

    @Test
    fun emptyProfilesAndLimits_onlyStaticSets() {
        val watched = calc()
        // Nessun pkg "applicativo" spurio: solo i set statici (browser, settings,
        // skip, self). Nessun crash sul caso vuoto.
        assertThat(watched).isEqualTo(browsers + settings + skip + SELF)
    }

    @Test
    fun dedupesPackageInBothProfileAndLimit() {
        // IG sia in un profilo sia con cap: una sola occorrenza (e' un Set).
        val watched = calc(
            profileApps = mapOf(1 to listOf(relation(IG))),
            limitPackages = setOf(IG),
        )
        assertThat(watched.count { it == IG }).isEqualTo(1)
    }
}
