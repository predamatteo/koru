package com.dev.koru.inventory

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI del predicato che decide cosa l'utente vede nelle liste e nelle
 * statistiche. Nessun Robolectric: [PackageVisibility] non tocca Android
 * apposta, così questa regola — che prima viveva sparsa in quattro punti con
 * criteri diversi — ha un solo posto in cui essere sbagliata.
 */
class PackageVisibilityTest {

    private val KORU = "com.dev.koru"
    private val IG = "com.instagram.android"
    private val YT = "com.google.android.youtube"
    private val SETTINGS = "com.android.settings"
    private val SYSTEMUI = "com.android.systemui"
    private val IME = "com.google.android.inputmethod.latin"
    private val NOVA = "com.teslacoilsw.launcher"
    private val PIXEL_LAUNCHER = "com.google.android.apps.nexuslauncher"

    private val launchable = setOf(KORU, IG, YT, SETTINGS, NOVA, PIXEL_LAUNCHER)
    private val home = setOf(KORU, NOVA, PIXEL_LAUNCHER)
    private val skip = setOf("android", SYSTEMUI, PIXEL_LAUNCHER)

    private fun visible(pkg: String, keepSelf: Boolean = false) =
        PackageVisibility.isUserFacing(
            pkg = pkg,
            selfPackage = KORU,
            launchablePackages = launchable,
            homePackages = home,
            skipPackages = skip,
            keepSelf = keepSelf,
        )

    @Test
    fun keepsOrdinaryApps() {
        assertThat(visible(IG)).isTrue()
        assertThat(visible(YT)).isTrue()
    }

    @Test
    fun keepsSystemAppsThatHaveAnIcon() {
        // "App di sistema" NON significa FLAG_SYSTEM: su un Pixel YouTube,
        // Chrome e Gmail sono preinstallate. Il criterio è "apribile e non
        // launcher", altrimenti nasconderemmo proprio le app da limitare.
        assertThat(visible(SETTINGS)).isTrue()
    }

    @Test
    fun dropsFrameworkAndSystemUi() {
        assertThat(visible(SYSTEMUI)).isFalse()
        assertThat(visible("android")).isFalse()
    }

    @Test
    fun dropsNonLaunchableComponents() {
        // IME, componenti Play, servizi di background: accumulano foreground
        // ma non hanno un'icona.
        assertThat(visible(IME)).isFalse()
    }

    @Test
    fun dropsThirdPartyLaunchersEvenWhenNotInTheDenylist() {
        // È il motivo per cui il criterio è CATEGORY_HOME e non SKIP_PACKAGES:
        // Nova è launchable e NON è nella denylist hardcoded, quindi con il
        // vecchio filtro compariva nel widget e nelle statistiche.
        assertThat(skip).doesNotContain(NOVA)
        assertThat(visible(NOVA)).isFalse()
    }

    @Test
    fun dropsSelfByDefaultButKeepsItForTheDrawer() {
        // Le due metà del caso speciale Koru: fuori dalle statistiche (come
        // launcher predefinito monopolizzerebbe la classifica), dentro il
        // drawer (chi ha cambiato launcher deve poterla riaprire da lì).
        assertThat(visible(KORU)).isFalse()
        assertThat(visible(KORU, keepSelf = true)).isTrue()
    }

    @Test
    fun dropsEmptyPackageName() {
        assertThat(visible("")).isFalse()
    }

    @Test
    fun failsOpenWhenTheLaunchableQueryReturnsNothing() {
        // Set vuoto = PackageManager ha fallito, non "device senza app". In
        // quel caso il filtro launchable si spegne invece di svuotare liste e
        // statistiche — ma launcher, skip-list e self restano esclusi.
        fun v(pkg: String) = PackageVisibility.isUserFacing(
            pkg = pkg,
            selfPackage = KORU,
            launchablePackages = emptySet(),
            homePackages = home,
            skipPackages = skip,
        )

        assertThat(v(IME)).isTrue() // niente filtro launchable
        assertThat(v(IG)).isTrue()
        assertThat(v(NOVA)).isFalse()
        assertThat(v(SYSTEMUI)).isFalse()
        assertThat(v(KORU)).isFalse()
    }

    @Test
    fun filterUserFacingKeepsOnlyVisibleKeys() {
        val filtered = PackageVisibility.filterUserFacing(
            usage = mapOf(IG to 40L, KORU to 20L, SYSTEMUI to 5L, NOVA to 3L, YT to 7L),
            selfPackage = KORU,
            launchablePackages = launchable,
            homePackages = home,
            skipPackages = skip,
        )

        assertThat(filtered).containsExactly(IG, 40L, YT, 7L)
    }

    @Test
    fun filterUserFacingIsWhatMakesTheWidgetTotalMatchTheApp() {
        // Widget e schermata Statistiche passano dallo STESSO predicato: se le
        // due somme divergono, è perché qualcuno ha filtrato una sponda sola.
        val raw = mapOf(IG to 40L, KORU to 20L, SYSTEMUI to 5L)
        val filtered = PackageVisibility.filterUserFacing(
            usage = raw,
            selfPackage = KORU,
            launchablePackages = launchable,
            homePackages = home,
            skipPackages = skip,
        )

        assertThat(filtered.values.sum()).isEqualTo(40L)
        assertThat(raw.values.sum()).isEqualTo(65L)
    }
}
