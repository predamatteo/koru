package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [RecentsDetector]. Due consumatori con tolleranze diverse:
 * [isRecentsWindow] (strict mode, opt-in: stessi pattern della versione inline
 * storica di StrictModeEnforcer — questo test li pinna contro regressioni) e
 * [isRecentsHostWindow] (gate del launcher, always-on: niente falsi positivi
 * su app terze).
 */
class RecentsDetectorTest {

    private val SELF = "com.dev.koru"
    private val SKIP = setOf(
        "android",
        "com.android.systemui",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.miui.home",
        "com.sec.android.app.launcher",
    )

    // ─── isRecentsWindow: positivi (pattern storici, pinnati) ───────────────

    @Test
    fun quickstepOnePlus_matches() {
        // Il device di test (OnePlus 8T, OxygenOS 14): verificato via dumpsys.
        assertThat(
            RecentsDetector.isRecentsWindow(
                "com.android.launcher", "com.android.quickstep.RecentsActivity",
            ),
        ).isTrue()
    }

    @Test
    fun quickstepFallback_matches() {
        assertThat(
            RecentsDetector.isRecentsWindow(
                "com.google.android.apps.nexuslauncher",
                "com.android.quickstep.fallback.RecentsActivity",
            ),
        ).isTrue()
    }

    @Test
    fun miuiRecents_matches() {
        assertThat(
            RecentsDetector.isRecentsWindow(
                "com.miui.home", "com.miui.home.recents.RecentsActivity",
            ),
        ).isTrue()
    }

    @Test
    fun legacySystemUiRecents_matches() {
        assertThat(
            RecentsDetector.isRecentsWindow(
                "com.android.systemui", "com.android.systemui.recents.RecentsActivity",
            ),
        ).isTrue()
    }

    @Test
    fun legacyOemRecentTaskAndOverviewPanel_match() {
        assertThat(
            RecentsDetector.isRecentsWindow("com.oneplus.launcher", "RecentTaskPanelView"),
        ).isTrue()
        assertThat(
            RecentsDetector.isRecentsWindow("com.sec.android.app.launcher", "OverviewPanel"),
        ).isTrue()
    }

    @Test
    fun launcherPackageWithBareRecentClassName_matches() {
        // Quarto ramo: pkg launcher + className con "Recent" (senza la "s").
        assertThat(
            RecentsDetector.isRecentsWindow("com.oppo.launcher", "RecentContainerView"),
        ).isTrue()
    }

    // ─── isRecentsWindow: negativi ──────────────────────────────────────────

    @Test
    fun systemUiShade_doesNotMatch() {
        // Il bug storico: il pull-down della shade ha pkg systemui ma NON è
        // recents — il match è SOLO su className.
        assertThat(
            RecentsDetector.isRecentsWindow(
                "com.android.systemui", "com.android.systemui.statusbar.phone.StatusBar",
            ),
        ).isFalse()
        assertThat(
            RecentsDetector.isRecentsWindow("com.android.systemui", "QSPanel"),
        ).isFalse()
    }

    @Test
    fun koruMainActivity_doesNotMatch() {
        assertThat(
            RecentsDetector.isRecentsWindow("com.dev.koru", "com.dev.koru.MainActivity"),
        ).isFalse()
    }

    // ─── isRecentsHostWindow: il gate richiede anche un host plausibile ─────

    private fun host(pkg: String, cls: String) =
        RecentsDetector.isRecentsHostWindow(pkg, cls, SELF, SKIP)

    @Test
    fun hostWindow_quickstepOnDevice_matches() {
        assertThat(host("com.android.launcher", "com.android.quickstep.RecentsActivity"))
            .isTrue()
    }

    @Test
    fun hostWindow_thirdPartyAppWithRecentsClassName_doesNotMatch() {
        // Always-on: un'app qualsiasi con "Recents" in un className non deve
        // far scattare il gate (lo strict mode opt-in invece la matcha).
        assertThat(host("com.example.notes", "RecentsListActivity")).isFalse()
        assertThat(
            RecentsDetector.isRecentsWindow("com.example.notes", "RecentsListActivity"),
        ).isTrue()
    }

    @Test
    fun hostWindow_selfNeverMatches() {
        assertThat(host(SELF, "RecentsActivity")).isFalse()
    }

    @Test
    fun hostWindow_emptyPackage_doesNotMatch() {
        assertThat(host("", "RecentsActivity")).isFalse()
    }

    @Test
    fun hostWindow_oemLauncherNotInSkipSet_matchesViaSubstring() {
        // Launcher OEM non elencato in SKIP: passa via contains("launcher").
        assertThat(host("com.vivo.launcher", "VivoRecentsActivity")).isTrue()
    }

    // ─── isClearAllNode ──────────────────────────────────────────────────────

    @Test
    fun clearAllByViewId_matches() {
        assertThat(
            RecentsDetector.isClearAllNode("com.android.launcher:id/clear_all", null),
        ).isTrue()
        assertThat(
            RecentsDetector.isClearAllNode("com.miui.home:id/clearAnimView", null),
        ).isFalse()
    }

    @Test
    fun clearAllByText_matchesKnownLocales() {
        assertThat(RecentsDetector.isClearAllNode(null, "Clear all")).isTrue()
        assertThat(RecentsDetector.isClearAllNode(null, "Cancella tutto")).isTrue()
        assertThat(RecentsDetector.isClearAllNode(null, "  clear ALL  ")).isTrue()
    }

    @Test
    fun ordinaryNode_doesNotMatch() {
        assertThat(RecentsDetector.isClearAllNode("com.android.launcher:id/snapshot", "WhatsApp"))
            .isFalse()
        assertThat(RecentsDetector.isClearAllNode(null, null)).isFalse()
    }
}
