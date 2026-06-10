package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI della logica di [OpenAppsTracker]: filtro [shouldTrack] e calcolo
 * della finestra di sweep [sweepWindowStartMs]. La parte UsageStats/PM è
 * integrazione (verificata on-device).
 */
class OpenAppsTrackerTest {

    private val SELF = "com.dev.koru"
    private val SKIP = setOf(
        "android",
        "com.android.systemui",
        "com.android.launcher",
        "com.oneplus.launcher",
    )

    private fun track(pkg: String, launchable: Boolean = true) =
        OpenAppsTracker.shouldTrack(pkg, SELF, SKIP, launchable)

    // ─── shouldTrack ─────────────────────────────────────────────────────────

    @Test
    fun realLaunchableApp_isTracked() {
        assertThat(track("com.whatsapp")).isTrue()
    }

    @Test
    fun settingsApp_isTracked() {
        // Decisione di design: Settings è un task visibile nelle recents →
        // conta come scheda (le esclusioni sono solo self/skip/non-launchable).
        assertThat(track("com.android.settings")).isTrue()
    }

    @Test
    fun selfAndSkipSet_areNeverTracked() {
        assertThat(track(SELF)).isFalse()
        assertThat(track("android")).isFalse()
        assertThat(track("com.android.systemui")).isFalse()
        assertThat(track("com.android.launcher")).isFalse()
    }

    @Test
    fun nonLaunchablePackages_areNotTracked() {
        // IME, permission dialogs, resolver: niente launch intent → fuori.
        assertThat(track("com.google.android.inputmethod.latin", launchable = false)).isFalse()
        assertThat(track("com.google.android.permissioncontroller", launchable = false)).isFalse()
    }

    @Test
    fun emptyPackage_isNotTracked() {
        assertThat(track("")).isFalse()
    }

    // ─── sweepWindowStartMs ──────────────────────────────────────────────────

    private val BOOT = 1_000_000L

    @Test
    fun firstSweep_startsAtBoot() {
        val start = OpenAppsTracker.sweepWindowStartMs(
            bootWallMs = BOOT, resetWallMs = 0L, lastSweepEndWallMs = 0L, overlapMs = 2_000L,
        )
        assertThat(start).isEqualTo(BOOT)
    }

    @Test
    fun incrementalSweep_overlapsPreviousWindow() {
        val start = OpenAppsTracker.sweepWindowStartMs(
            bootWallMs = BOOT, resetWallMs = 0L, lastSweepEndWallMs = BOOT + 60_000L, overlapMs = 2_000L,
        )
        assertThat(start).isEqualTo(BOOT + 58_000L)
    }

    @Test
    fun resetAnchor_winsOverBootAndIncrement() {
        val reset = BOOT + 100_000L
        val start = OpenAppsTracker.sweepWindowStartMs(
            bootWallMs = BOOT, resetWallMs = reset, lastSweepEndWallMs = BOOT + 60_000L, overlapMs = 2_000L,
        )
        assertThat(start).isEqualTo(reset)
    }

    @Test
    fun staleResetAnchorFromPreviousBoot_isNeutralizedByBootTime() {
        // Reboot DOPO il reset: bootTime corrente > vecchia ancora → vince il
        // boot, l'ancora persistita del boot precedente è innocua.
        val staleReset = BOOT - 500_000L
        val start = OpenAppsTracker.sweepWindowStartMs(
            bootWallMs = BOOT, resetWallMs = staleReset, lastSweepEndWallMs = 0L, overlapMs = 2_000L,
        )
        assertThat(start).isEqualTo(BOOT)
    }

    @Test
    fun overlapNeverUnderflowsBeforeBoot() {
        // Sweep incrementale subito dopo il boot: l'overlap non deve far
        // retrocedere la finestra prima del boot.
        val start = OpenAppsTracker.sweepWindowStartMs(
            bootWallMs = BOOT, resetWallMs = 0L, lastSweepEndWallMs = BOOT + 1_000L, overlapMs = 2_000L,
        )
        assertThat(start).isEqualTo(BOOT)
    }

    // ─── computeRecentsSync (sync con le card reali delle recents) ──────────

    private val BIG_TREE = OpenAppsTracker.MIN_NODES_FOR_EMPTY_TRUTH + 10

    @Test
    fun emptyRecents_clearsTheCount() {
        // Il bug riportato: count=1 (WhatsApp) ma recents svuotate con lo
        // swipe della singola card. Scan: albero sostanzioso, zero card,
        // niente bottone clear-all (quickstep lo nasconde a recents vuote).
        val next = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = emptySet(),
            sawClearAll = false,
            visitedNodes = BIG_TREE,
        )
        assertThat(next).isEmpty()
    }

    @Test
    fun zeroMatchesButClearAllPresent_isNotEmptinessTruth() {
        // Card esistenti ma label non mappate: il bottone clear-all c'è →
        // NON azzerare (meglio stale che falso zero).
        val next = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = emptySet(),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(next).isNull()
    }

    @Test
    fun zeroMatchesOnTinyTree_isNotEmptinessTruth() {
        // Scan partito troppo presto (albero non popolato): no-op.
        val next = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = emptySet(),
            sawClearAll = false,
            visitedNodes = OpenAppsTracker.MIN_NODES_FOR_EMPTY_TRUTH - 1,
        )
        assertThat(next).isNull()
    }

    @Test
    fun matchedCards_replaceTheSet_bothDirections() {
        // Dismiss di una card su due → shrink; card presente ma non tracciata
        // (es. aperta prima di un reset manuale) → re-add: la verità vince.
        val shrunk = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp", "com.spotify.music"),
            matched = setOf("com.spotify.music"),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(shrunk).containsExactly("com.spotify.music")

        val readded = OpenAppsTracker.computeRecentsSync(
            current = emptySet(),
            matched = setOf("com.whatsapp"),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(readded).containsExactly("com.whatsapp")
    }

    @Test
    fun unchangedSet_isNoOp() {
        val next = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = setOf("com.whatsapp"),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(next).isNull()
    }

    // ─── matchCardDescription ────────────────────────────────────────────────

    private val LABELS = mapOf("whatsapp" to "com.whatsapp", "spotify" to "com.spotify.music")

    @Test
    fun cardDescription_exactAndCommaSuffixed_match() {
        assertThat(OpenAppsTracker.matchCardDescription("WhatsApp", LABELS))
            .isEqualTo("com.whatsapp")
        assertThat(OpenAppsTracker.matchCardDescription("  Spotify  ", LABELS))
            .isEqualTo("com.spotify.music")
        // Alcune build accodano stato/timestamp alla description della card.
        assertThat(OpenAppsTracker.matchCardDescription("WhatsApp, ultimo utilizzo 14:10", LABELS))
            .isEqualTo("com.whatsapp")
    }

    @Test
    fun cardDescription_unknownLabel_doesNotMatch() {
        assertThat(OpenAppsTracker.matchCardDescription("Cancella tutto", LABELS)).isNull()
        assertThat(OpenAppsTracker.matchCardDescription("Screenshot", LABELS)).isNull()
    }
}
