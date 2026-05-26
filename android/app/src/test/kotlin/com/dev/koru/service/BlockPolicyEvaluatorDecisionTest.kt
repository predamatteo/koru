package com.dev.koru.service

import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.overlay.BlockReason
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [BlockPolicyEvaluator.evaluate]: un caso per ogni ramo della
 * composizione + le regressioni di sicurezza. Lo stato di bypass è iniettato
 * via lo stub [bypassReasonFor] (niente BypassStore / Keystore / Robolectric).
 *
 * Avversario: l'utente che cerca di aggirare i propri limiti. Le proprietà
 * chiave verificate qui:
 * - focus vince sul daily limit;
 * - cap STRICT ignora qualsiasi bypass; cap non-strict sospeso SOLO da un
 *   limit-bypass;
 * - un bypass di PROFILO (whole-app) NON ricarica il cap;
 * - bypass di sezione scoped a `section:<wireId>` (CR-07);
 * - bypass di sito scoped al dominio.
 */
class BlockPolicyEvaluatorDecisionTest {

    private val PKG = "com.app"
    private val MON = 1

    private fun profile(id: Int = 1, blockingMode: Int = 0) = NativeProfile(
        id = id,
        title = "Profilo $id",
        typeCombinations = 0,
        onConditions = 0,
        operator = 0,
        dayFlags = MON,
        blockNotifications = false,
        blockLaunch = false,
        isEnabled = true,
        isLocked = false,
        onUntil = 0L,
        lockedUntil = 0L,
        pausedUntil = 0L,
        blockingMode = blockingMode,
        blockUnsupportedBrowsers = false,
        blockAdultContent = false,
        colorHex = "#5C8262",
        emoji = "E$id",
    )

    private fun relation(
        pkg: String = PKG,
        isEnabled: Boolean = true,
        blockedSectionsJson: String? = null,
    ) = NativeAppRelation(pkg, 1, isEnabled, null, blockedSectionsJson)

    /** Stub bypass: ritorna [reason] solo per lo [scope] richiesto. */
    private fun bypassStub(scope: String?, reason: BlockReason?): (String?) -> BlockReason? =
        { s -> if (s == scope) reason else null }

    private val noBypass: (String?) -> BlockReason? = { null }

    private fun query(
        profiles: List<NativeProfile> = emptyList(),
        profileApps: Map<Int, List<NativeAppRelation>> = emptyMap(),
        limitMinutes: Int = 0,
        isLimitStrict: Boolean = false,
        limitTodayMs: Long = 0L,
        focusShouldBlock: Boolean = false,
        bypassReasonFor: (String?) -> BlockReason? = noBypass,
        websiteScopeDomain: String? = null,
        sectionWireId: String? = null,
    ) = BlockQuery(
        packageName = PKG,
        profiles = profiles,
        profileApps = profileApps,
        profileIntervals = emptyMap(),
        profileWifis = emptyMap(),
        limitMinutes = limitMinutes,
        isLimitStrict = isLimitStrict,
        limitTodayMs = limitTodayMs,
        focusShouldBlock = focusShouldBlock,
        bypassReasonFor = bypassReasonFor,
        nowWallMs = 1_000L,
        nowMinutesOfDay = 12 * 60,
        todayDayFlag = MON,
        currentWifiSsid = null,
        websiteScopeDomain = websiteScopeDomain,
        sectionWireId = sectionWireId,
    )

    // ---- 1) Focus -----------------------------------------------------------

    @Test
    fun focus_blocksWithFocusReason() {
        val d = BlockPolicyEvaluator.evaluate(query(focusShouldBlock = true))
        assertThat(d).isInstanceOf(BlockDecision.Block::class.java)
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.FOCUS_MODE)
        assertThat(d.profileId).isNull()
    }

    @Test
    fun focus_winsOverDailyLimit() {
        // Focus E cap superato: deve vincere FOCUS_MODE (è il ramo 1).
        val d = BlockPolicyEvaluator.evaluate(
            query(focusShouldBlock = true, limitMinutes = 30, limitTodayMs = 60 * 60_000L),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.FOCUS_MODE)
    }

    // ---- 2) Daily limit -----------------------------------------------------

    @Test
    fun limit_capReached_blocks() {
        val d = BlockPolicyEvaluator.evaluate(
            query(limitMinutes = 30, isLimitStrict = false, limitTodayMs = 30 * 60_000L),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.USAGE_LIMIT)
        assertThat(d.isStrictLimit).isFalse()
        assertThat(d.todayMs).isEqualTo(30 * 60_000L)
        assertThat(d.limitMs).isEqualTo(30 * 60_000L)
    }

    @Test
    fun limit_belowCap_doesNotBlock() {
        val d = BlockPolicyEvaluator.evaluate(
            query(limitMinutes = 30, limitTodayMs = 29 * 60_000L),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun limit_strict_blocksDespiteActiveLimitBypass() {
        // STRICT ⇒ hard cap: blocca anche con un limit-bypass attivo.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                limitMinutes = 30,
                isLimitStrict = true,
                limitTodayMs = 30 * 60_000L,
                bypassReasonFor = bypassStub(null, BlockReason.USAGE_LIMIT),
            ),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.USAGE_LIMIT)
        assertThat(d.isStrictLimit).isTrue()
    }

    @Test
    fun limit_nonStrict_suppressedByLimitBypass() {
        // NON-strict + limit-bypass (USAGE_LIMIT) attivo ⇒ cap sospeso ⇒ Allow.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                limitMinutes = 30,
                isLimitStrict = false,
                limitTodayMs = 30 * 60_000L,
                bypassReasonFor = bypassStub(null, BlockReason.USAGE_LIMIT),
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun limit_nonStrict_bypassExpiredAlsoSuppresses() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                limitMinutes = 30,
                isLimitStrict = false,
                limitTodayMs = 30 * 60_000L,
                bypassReasonFor = bypassStub(null, BlockReason.BYPASS_EXPIRED),
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun limit_appBypassDoesNotReloadCap_stillBlocks() {
        // Un bypass di PROFILO (APP_BLOCKED) NON è un limit-bypass: il cap
        // resta esigibile anche non-strict (bug "+5 min all'infinito").
        val d = BlockPolicyEvaluator.evaluate(
            query(
                limitMinutes = 30,
                isLimitStrict = false,
                limitTodayMs = 30 * 60_000L,
                bypassReasonFor = bypassStub(null, BlockReason.APP_BLOCKED),
            ),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.USAGE_LIMIT)
    }

    // ---- 3) Whole-app bypass short-circuit ----------------------------------

    @Test
    fun appBypass_belowCap_allowsAndShortCircuitsProfiles() {
        // Bypass di profilo attivo + cap non raggiunto ⇒ Allow, anche se un
        // profilo bloccherebbe l'app.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile(blockingMode = 0)),
                profileApps = mapOf(1 to listOf(relation())),
                limitMinutes = 30,
                limitTodayMs = 10 * 60_000L,
                bypassReasonFor = bypassStub(null, BlockReason.APP_BLOCKED),
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    // ---- 4) APP match -------------------------------------------------------

    @Test
    fun app_blocklist_contains_blocks() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile(blockingMode = 0)),
                profileApps = mapOf(1 to listOf(relation(isEnabled = true))),
            ),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.APP_BLOCKED)
        assertThat(d.profileId).isEqualTo(1)
        assertThat(d.relation).isNotNull()
    }

    @Test
    fun app_blocklist_disabledRelation_doesNotBlock() {
        // Relation con isEnabled=false non entra nella blocklist effettiva.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile(blockingMode = 0)),
                profileApps = mapOf(1 to listOf(relation(isEnabled = false))),
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun app_allowlist_notInList_blocks() {
        // Allowlist (mode=1) non vuota e pkg NON presente ⇒ blocca.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile(blockingMode = 1)),
                profileApps = mapOf(1 to listOf(relation(pkg = "com.other", isEnabled = true))),
            ),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.APP_BLOCKED)
    }

    @Test
    fun app_allowlist_inList_doesNotBlock() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile(blockingMode = 1)),
                profileApps = mapOf(1 to listOf(relation(pkg = PKG, isEnabled = true))),
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun app_inactiveProfile_doesNotBlock() {
        // Profilo non attivo ORA (giorno diverso) ⇒ Allow.
        val inactive = profile(blockingMode = 0).copy(dayFlags = 2 /* TUE */)
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(inactive),
                profileApps = mapOf(1 to listOf(relation())),
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    // ---- 5) SECTION match (CR-07) -------------------------------------------

    @Test
    fun section_noBypass_blocksWithScopedDomain() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                profileApps = mapOf(
                    1 to listOf(relation(isEnabled = false, blockedSectionsJson = "[\"reels\"]")),
                ),
                sectionWireId = "reels",
            ),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.SECTION_BLOCKED)
        assertThat(d.bypassScopeDomain).isEqualTo("section:reels")
    }

    @Test
    fun section_withScopedBypass_allows() {
        // CR-07 regression: bypass keyed a section:reels ⇒ Allow.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                profileApps = mapOf(
                    1 to listOf(relation(isEnabled = false, blockedSectionsJson = "[\"reels\"]")),
                ),
                bypassReasonFor = bypassStub("section:reels", BlockReason.SECTION_BLOCKED),
                sectionWireId = "reels",
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun section_bypassScopeRoundTrips_blockScopeIsTheGuardKey() {
        // CR-07 contract end-to-end: lo scope che il Block produce
        // (bypassScopeDomain → passato come blockedDomain all'overlay, quindi
        // usato come chiave di markBypassed) DEVE essere ESATTAMENTE la chiave
        // che il guard rilegge. Catturiamo lo scope dal primo Block e lo
        // ri-iniettiamo come bypass: la seconda valutazione deve dare Allow.
        // Se un domani lo scope del mark e quello del guard divergono (il bug
        // CR-07), questo test fallisce.
        val first = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                profileApps = mapOf(
                    1 to listOf(relation(isEnabled = false, blockedSectionsJson = "[\"shorts\"]")),
                ),
                sectionWireId = "shorts",
            ),
        )
        val scope = (first as BlockDecision.Block).bypassScopeDomain
        assertThat(scope).isEqualTo("section:shorts")

        val second = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                profileApps = mapOf(
                    1 to listOf(relation(isEnabled = false, blockedSectionsJson = "[\"shorts\"]")),
                ),
                bypassReasonFor = bypassStub(scope, BlockReason.SECTION_BLOCKED),
                sectionWireId = "shorts",
            ),
        )
        assertThat(second).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun section_appFullyBlocked_skippedHere() {
        // relation.isEnabled=true ⇒ app bloccata interamente, gestita dal path
        // APP, non dal path SECTION ⇒ qui Allow.
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                profileApps = mapOf(
                    1 to listOf(relation(isEnabled = true, blockedSectionsJson = "[\"reels\"]")),
                ),
                sectionWireId = "reels",
            ),
        )
        // mode=0 + relation enabled ⇒ il path APP blocca prima ⇒ APP_BLOCKED.
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.APP_BLOCKED)
    }

    @Test
    fun section_wireIdNotInJson_doesNotBlock() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                profileApps = mapOf(
                    1 to listOf(relation(isEnabled = false, blockedSectionsJson = "[\"shorts\"]")),
                ),
                sectionWireId = "reels",
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    // ---- 6) WEBSITE match ---------------------------------------------------

    @Test
    fun website_noBypass_blocksWithScopeDomain() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                websiteScopeDomain = "reddit",
            ),
        )
        assertThat((d as BlockDecision.Block).reason).isEqualTo(BlockReason.WEBSITE_BLOCKED)
        assertThat(d.bypassScopeDomain).isEqualTo("reddit")
    }

    @Test
    fun website_withDomainBypass_allows() {
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(profile()),
                bypassReasonFor = bypassStub("reddit", BlockReason.WEBSITE_BLOCKED),
                websiteScopeDomain = "reddit",
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    @Test
    fun website_inactiveProfile_doesNotBlock() {
        val inactive = profile().copy(dayFlags = 2 /* TUE */)
        val d = BlockPolicyEvaluator.evaluate(
            query(
                profiles = listOf(inactive),
                websiteScopeDomain = "reddit",
            ),
        )
        assertThat(d).isEqualTo(BlockDecision.Allow)
    }

    // ---- 7) else Allow ------------------------------------------------------

    @Test
    fun nothingMatches_allows() {
        assertThat(BlockPolicyEvaluator.evaluate(query())).isEqualTo(BlockDecision.Allow)
    }
}
