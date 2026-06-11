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

    private fun sweepStart(
        resetWallMs: Long = 0L,
        lastSweepEndWallMs: Long = 0L,
        recentsSyncFloorWallMs: Long = 0L,
    ) = OpenAppsTracker.sweepWindowStartMs(
        bootWallMs = BOOT,
        resetWallMs = resetWallMs,
        lastSweepEndWallMs = lastSweepEndWallMs,
        overlapMs = 2_000L,
        recentsSyncFloorWallMs = recentsSyncFloorWallMs,
    )

    @Test
    fun firstSweep_startsAtBoot() {
        assertThat(sweepStart()).isEqualTo(BOOT)
    }

    @Test
    fun incrementalSweep_overlapsPreviousWindow() {
        assertThat(sweepStart(lastSweepEndWallMs = BOOT + 60_000L))
            .isEqualTo(BOOT + 58_000L)
    }

    @Test
    fun resetAnchor_winsOverBootAndIncrement() {
        val reset = BOOT + 100_000L
        assertThat(sweepStart(resetWallMs = reset, lastSweepEndWallMs = BOOT + 60_000L))
            .isEqualTo(reset)
    }

    @Test
    fun staleResetAnchorFromPreviousBoot_isNeutralizedByBootTime() {
        // Reboot DOPO il reset: bootTime corrente > vecchia ancora → vince il
        // boot, l'ancora persistita del boot precedente è innocua.
        assertThat(sweepStart(resetWallMs = BOOT - 500_000L)).isEqualTo(BOOT)
    }

    @Test
    fun overlapNeverUnderflowsBeforeBoot() {
        // Sweep incrementale subito dopo il boot: l'overlap non deve far
        // retrocedere la finestra prima del boot.
        assertThat(sweepStart(lastSweepEndWallMs = BOOT + 1_000L)).isEqualTo(BOOT)
    }

    @Test
    fun syncFloor_winsOverIncrementalOverlap() {
        // Floor e ultima sweep allo stesso istante T: il floor NON subisce
        // l'overlap — la finestra parte da T, non da T-2s (il buco di 2s
        // permetteva la resurrezione di una scheda appena swipe-ata via).
        val t = BOOT + 60_000L
        assertThat(sweepStart(lastSweepEndWallMs = t, recentsSyncFloorWallMs = t))
            .isEqualTo(t)
    }

    // ─── computeRecentsSync (sync con le card reali delle recents) ──────────

    private val BIG_TREE = OpenAppsTracker.MIN_NODES_FOR_EMPTY_TRUTH + 10

    @Test
    fun emptyRecents_clearsTheCount() {
        // Il bug riportato: count=1 (WhatsApp) ma recents svuotate con lo
        // swipe della singola card. Scan: albero sostanzioso, zero card,
        // niente bottone clear-all (quickstep lo nasconde a recents vuote).
        val decision = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = emptySet(),
            sawClearAll = false,
            visitedNodes = BIG_TREE,
        )
        assertThat(decision)
            .isEqualTo(OpenAppsTracker.RecentsSyncDecision.Apply(emptySet()))
    }

    @Test
    fun zeroMatchesWithClearAll_suggestsRetry() {
        // Ambiguo: o card con label non mappate (no-op definitivo) o
        // animazione di "Cancella tutto" in corso (le card spariscono PRIMA
        // del bottone). Non si tocca il set MA si suggerisce un re-scan
        // ravvicinato che disambigua a bottone sparito.
        val decision = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = emptySet(),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(decision).isEqualTo(OpenAppsTracker.RecentsSyncDecision.RetryLater)
    }

    @Test
    fun zeroMatchesWithClearAll_currentEmpty_isNoOp() {
        // Set già vuoto: niente da azzerare, niente retry da sprecare.
        val decision = OpenAppsTracker.computeRecentsSync(
            current = emptySet(),
            matched = emptySet(),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(decision).isEqualTo(OpenAppsTracker.RecentsSyncDecision.NoOp)
    }

    @Test
    fun tinyTree_isNoOp_notRetry() {
        // Scan partito troppo presto (albero non popolato, niente clear-all
        // visto): no-op, non retry — il burst/trailing copre già il seguito.
        val decision = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = emptySet(),
            sawClearAll = false,
            visitedNodes = OpenAppsTracker.MIN_NODES_FOR_EMPTY_TRUTH - 1,
        )
        assertThat(decision).isEqualTo(OpenAppsTracker.RecentsSyncDecision.NoOp)
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
        assertThat(shrunk)
            .isEqualTo(OpenAppsTracker.RecentsSyncDecision.Apply(setOf("com.spotify.music")))

        val readded = OpenAppsTracker.computeRecentsSync(
            current = emptySet(),
            matched = setOf("com.whatsapp"),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(readded)
            .isEqualTo(OpenAppsTracker.RecentsSyncDecision.Apply(setOf("com.whatsapp")))
    }

    @Test
    fun unchangedSet_isNoOp() {
        val decision = OpenAppsTracker.computeRecentsSync(
            current = setOf("com.whatsapp"),
            matched = setOf("com.whatsapp"),
            sawClearAll = true,
            visitedNodes = BIG_TREE,
        )
        assertThat(decision).isEqualTo(OpenAppsTracker.RecentsSyncDecision.NoOp)
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

    // ─── applyRecentsResult (transizione set + ancore) ───────────────────────

    @Test
    fun applyRecentsResult_replacesSetAndAdvancesAnchors() {
        OpenAppsTracker.debugResetInMemoryState()
        val t0 = BOOT + 10_000L
        val t1 = BOOT + 20_000L
        OpenAppsTracker.applyRecentsResult(setOf("com.whatsapp"), t0)
        assertThat(OpenAppsTracker.debugTrackedSnapshot()).containsExactly("com.whatsapp")
        OpenAppsTracker.applyRecentsResult(emptySet(), t1)
        assertThat(OpenAppsTracker.debugTrackedSnapshot()).isEmpty()
        assertThat(OpenAppsTracker.debugLastSweepEndWallMs()).isEqualTo(t1)
        assertThat(OpenAppsTracker.debugRecentsSyncFloorWallMs()).isEqualTo(t1)
    }

    @Test
    fun resurrectionScenario_postSyncSweepExcludesPreSyncEvents() {
        // Il bug pinnato: WhatsApp RESUMED a t1, swipe-ato via dalle recents
        // a t2 (sync → set vuoto). La sweep al resume del launcher NON deve
        // ripartire da prima di t1 (overlap incluso), altrimenti WhatsApp
        // risuscita e il badge resta sul conteggio vecchio.
        OpenAppsTracker.debugResetInMemoryState()
        val t1 = BOOT + 50_000L // ACTIVITY_RESUMED di WhatsApp
        val t2 = t1 + 30_000L // sync con recents svuotate
        OpenAppsTracker.applyRecentsResult(emptySet(), t2)
        val start = OpenAppsTracker.sweepWindowStartMs(
            bootWallMs = BOOT,
            resetWallMs = 0L,
            lastSweepEndWallMs = OpenAppsTracker.debugLastSweepEndWallMs(),
            overlapMs = OpenAppsTracker.SWEEP_OVERLAP_MS,
            recentsSyncFloorWallMs = OpenAppsTracker.debugRecentsSyncFloorWallMs(),
        )
        assertThat(start).isEqualTo(t2)
        assertThat(start).isGreaterThan(t1)
    }
}
