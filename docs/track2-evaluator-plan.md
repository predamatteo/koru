# Track 2 Keystone — BlockPolicyEvaluator Refactor (build-ready spec)

Closes **CR-01, CR-02, CR-03, CR-06, CR-07, ARCH-01/02**. Full finding detail in `docs/review-2026-05-26.md`.
Goal: ONE pure-Kotlin `BlockPolicyEvaluator` + ONE canonical `isProfileActiveNow`; rewire all 4 native decision sites + the Dart "active now" check through equivalent logic; add parity/unit tests.

## Orchestrator refinements (REQUIRED, on top of the design below)
1. **Do NOT copy `getCurrentWifiSsid` into `LockRunnable` (R5).** Extract the existing `KoruAccessibilityService.getCurrentWifiSsid` logic into a shared helper (e.g. `service/WifiSsidProvider.kt` taking a `Context`, or a top-level `fun currentWifiSsid(context): String?`) and call it from BOTH the accessibility service and the backup. Copying it would recreate the exact parity-by-copy bug this refactor exists to kill.
2. **Include Flag B** in the Dart commit (C5): in `active_profile_provider.dart` filter intervals by `isEnabled` (`p.intervals.where((iv) => iv.isEnabled)`) to match the native `AND is_enabled = 1` query — otherwise the UI "active now" still diverges from native.
3. **Out of scope (do NOT do):** wiring/dropping the `isAllDayAuto` column (Flag A — leave it dead, note only), time-picker `from==to` validation (UI), and the accessibility-health-banner "website/section paused" surfacing (leave a `// TODO` + note only). Keep the diff to the evaluator + rewiring + tests + the Dart alignment.
4. **Commits:** follow the C1–C5 sequence below, one commit each, IN ORDER, committing each fully before the next (shared files). Convention: Italian, prefix `Fix:`/`Feat:`/`test:`, concise, reference finding ids; **NO `Co-Authored-By` / AI sign-off** (match `git log`). Commit on `main`. **Do NOT push** — the orchestrator verifies the full suite and the user pushes.
5. **Tests green at every commit.** Kotlin: `.\android\gradlew.bat -p android :app:testDebugUnitTest -x compileFlutterBuildDebug --console=plain` (module-scoped `:app:` — the bare task drags in `:shared_preferences_android` which has ~12 unrelated failures and halts). Dart: `flutter test`. The suite is currently GREEN (Kotlin 0 failures incl. the DetectedSection fix + migration skip; Dart 788/788) — keep it green. Under Robolectric the Keystore is unavailable, so encrypted-store paths fall back/skip — keep new pure tests Robolectric-free where possible (mirror `UsageGuardDecideTest`).

---

## 0. Confirmed divergences (the bug class) — anchors as of 2026-05-26
- `KoruAccessibilityService.kt`: `checkAppBlocking` ~803-1058, `checkInAppContentBlocking` ~1060-1124, `checkWebsiteBlocking` ~1126-1226, `isProfileActiveNow` ~1228-1282.
- `LockRunnable.kt`: `checkAndBlock` ~139-270, `isProfileActiveNow` ~289-323 (closed interval, no wifi, no focus, no website/section).
- `lib/core/utils/schedule_utils.dart`: `isNowInRange` ~12-23; caller `active_profile_provider.dart:16-38`.

Divergence axes: (1) interval boundary + `from==to` (half-open/24h vs closed/1-min vs half-open/never); (2) wifi (a11y only); (3) `onUntil` order (result identical — AND of predicates — but pick one); (4) focus/limit/bypass coverage (backup misses focus + never reads QuickBlockStore); (5) CR-07 section bypass guard missing.

## 1. New types (`android/app/src/main/kotlin/com/dev/koru/service/BlockPolicyEvaluator.kt`, pure — no Android calls)

```kotlin
sealed interface BlockDecision {
    object Allow : BlockDecision
    data class Block(
        val reason: BlockReason,            // reuse com.dev.koru.overlay.BlockReason
        val profileId: Int? = null,         // null for focus/daily-limit (global)
        val profileTitle: String,
        val profileEmoji: String? = null,
        val relation: NativeAppRelation? = null,  // for overlayConfigJson/blockedSectionsJson
        val bypassScopeDomain: String? = null,    // website=rule name; section="section:<wireId>"; else null
        val isStrictLimit: Boolean = false,
        val todayMs: Long = 0L,
        val limitMs: Long = 0L,
    ) : BlockDecision
}

data class BlockQuery(
    val packageName: String,
    val profiles: List<NativeProfile>,
    val profileApps: Map<Int, List<NativeAppRelation>>,
    val profileIntervals: Map<Int, List<NativeInterval>>,
    val profileWifis: Map<Int, Set<String>>,
    val limitMinutes: Int,            // 0 = none
    val isLimitStrict: Boolean,
    val limitTodayMs: Long,           // already guardedTodayForegroundMs (SEC-03 guard)
    val focusShouldBlock: Boolean,    // qbSnapshot.shouldBlock(pkg, nowWall) precomputed
    val bypassReasonFor: (scopeDomain: String?) -> BlockReason?,  // NON-defaulted (omission = compile error)
    val nowWallMs: Long,
    val nowMinutesOfDay: Int,         // 0..1439 local
    val todayDayFlag: Int,            // single bit for today
    val currentWifiSsid: String?,
    val websiteScopeDomain: String? = null,
    val sectionWireId: String? = null,
)

object BlockPolicyEvaluator {
    fun isProfileActiveNow(profile, intervals, wifiSet, nowWallMs, nowMinutesOfDay, todayDayFlag, currentWifiSsid): Boolean
    fun evaluate(q: BlockQuery): BlockDecision
    internal fun isNowInInterval(nowMinutes, fromMinutes, toMinutes): Boolean =
        when {
            fromMinutes == toMinutes -> true                                  // 24h (canonical)
            fromMinutes <  toMinutes -> nowMinutes in fromMinutes until toMinutes   // half-open
            else                     -> nowMinutes >= fromMinutes || nowMinutes < toMinutes // cross-midnight
        }
}
```

`isProfileActiveNow` body (lifted from accessibility `:1232-1281`, env injected — it is the correctness reference):
```
if (profile.pausedUntil < 0) return false
if (profile.pausedUntil > 0 && profile.pausedUntil > nowWallMs) return false
if (profile.dayFlags and todayDayFlag == 0) return false
if (profile.onUntil > 0 && nowWallMs > profile.onUntil) return false
val hasTime = (profile.typeCombinations and 1 /*TIME*/) != 0
if (hasTime && intervals.isNotEmpty() && intervals.none { isNowInInterval(nowMinutesOfDay, it.fromMinutes, it.toMinutes) }) return false
if (wifiSet != null && wifiSet.isNotEmpty() && (currentWifiSsid == null || currentWifiSsid !in wifiSet)) return false
return true
```
(Keep the in-code `pausedUntil` check even though SQL pre-filters it — needed for unit tests. Do NOT consult `isLocked`/`lockedUntil` — preserves current behavior.)

## 2. `evaluate` composition order (cross-checked vs all 3 a11y functions — drop NO guard)
1. **Focus/quick-block**: `if (q.focusShouldBlock)` → `Block(FOCUS_MODE, profileTitle="Focus session", profileEmoji="🎯")`. (Backup gains this — CR-01.)
2. **Daily limit (strict ignores bypass)**: `limitBypassActive = bypassReasonFor(null) in {USAGE_LIMIT, BYPASS_EXPIRED}`; if `limitMinutes>0 && limitTodayMs >= limitMinutes*60_000 && (isLimitStrict || !limitBypassActive)` → `Block(USAGE_LIMIT, isStrictLimit, todayMs, limitMs)`.
3. **Whole-app bypass short-circuit**: `if (bypassReasonFor(null) != null) return Allow` (adapter does `lastBypassedActiveForeground` bookkeeping + scheduleLimitCheck).
4. **APP match**: for each active profile (`isProfileActiveNow`): blocklist contains / allowlist (non-empty && !contains) → `Block(APP_BLOCKED, profileId, …, relation)`.
5. **SECTION match** (only if `sectionWireId != null`): active profile, relation exists, `!relation.isEnabled`, `blockedSectionsJson` contains wireId; **CR-07 guard**: `if (bypassReasonFor("section:$sectionWireId") != null) return Allow`; else `Block(SECTION_BLOCKED, …, relation, bypassScopeDomain="section:$sectionWireId")`.
6. **WEBSITE match** (only if `websiteScopeDomain != null`; adapter already ran `WebsiteMatcher`): bypass guard `if (bypassReasonFor(websiteScopeDomain) != null) return Allow`; else `Block(WEBSITE_BLOCKED, …, bypassScopeDomain=websiteScopeDomain)`.
7. else `Allow`.

Ghost-event guard (`checkAppBlocking:841-853`, ForegroundDetector) stays in the adapter, runs BEFORE building the query.

## 3. Adapters (side-effects stay in adapters; only the DECISION moves to the evaluator)
- **checkAppBlocking** (`:803-1058`): keep ghost guard; read QuickBlock/limits/usage as today; build `BlockQuery` (domain/section null); `when(evaluate)` renders the existing overlay/home/log/event blocks for FOCUS_MODE (`:861-890`), USAGE_LIMIT (`:936-973`), APP_BLOCKED (`:1007-1034`); `Allow` → existing dismiss/bookkeeping tail.
- **checkInAppContentBlocking** (`:1060-1124`): keep detector+debounce; build query with `sectionWireId=detected.wireId`; render SECTION_BLOCKED (`:1086-1120`). CR-07 guard now in evaluator. **Companion fix (CR-07):** in the SECTION_BLOCKED `OverlayManager.show(...)` pass `blockedDomain="section:$wireId"` (today it's null at `:1089-1098`) so a granted bypass keys to `section:<wireId>` (matches the guard).
- **checkWebsiteBlocking** (`:1126-1226`): keep `BrowserConfigLoader`/`BrowserUrlDetector`/cache guard/`WebsiteMatcher.firstMatch` + per-profile loop in adapter; for the matched profile build a query (`websiteScopeDomain=matchedRule.name.lowercase().trim()`, single-profile) → evaluator runs active-now + bypass guard; render WEBSITE_BLOCKED (`:1189-1224`).
- **LockRunnable.checkAndBlock** (`:139-270`): keep ForegroundDetector/auto-revoke/skipPackages/`instance!=null` step-aside/DB+callbacks. Replace `:198-269` with one `BlockQuery`+`evaluate`. NEW inputs: `focusShouldBlock` (read QuickBlockStore — CR-01), `currentWifiSsid` (via the SHARED helper — refinement #1, CR-03), `profileWifis`+unconditional intervals in `loadProfiles` (add `NativeDatabase.getWifiSsidsByProfile`). Render: FOCUS_MODE→new `onFocusBlock(pkg,label)` callback (add to ctor + wire in `LockForegroundService` ~:218 to show FOCUS_MODE + performGoHome + restrictionType=4); APP_BLOCKED→`onBlock`; USAGE_LIMIT→`onLimitBlock`; WEBSITE/SECTION **not reachable** (no node tree → document the intentional asymmetry, `// TODO` health-banner note); `Allow`→existing unblock (re-check `OverlayManager.isBypassed(pkg)` to preserve `lastBypassedForegroundPkg`). Delete `LockRunnable.isProfileActiveNow`.

## 4. Tests
- `BlockPolicyEvaluatorActiveNowTest.kt` (plain JUnit+Truth): `isNowInInterval` boundaries (from-1/from/to-1/to/midnight/from==to/cross-midnight 22:00→06:00) + `isProfileActiveNow` matrix (pausedUntil </>/0, dayFlags, onUntil, time-bit off, empty intervals, wifi match/miss/null).
- `BlockPolicyEvaluatorDecisionTest.kt` (plain JUnit+Truth): one per `evaluate` branch (focus>limit; strict limit blocks w/ active limit-bypass; non-strict suppressed by bypass; app-bypass⇒Allow but limit still blocks; blocklist; allowlist; section+bypass⇒Allow [CR-07 regression]; section no-bypass⇒Block scope `section:<wireId>`; website+bypass⇒Allow; website no-bypass⇒Block; inactive⇒Allow). Inject `bypassReasonFor` stub.
- `BlockPolicyParityTest.kt`: pin a hand-computed truth table over the boundary tuples so a future re-divergence fails; comment "every new decision site MUST call the evaluator".
- Extend `test/utils/schedule_utils_test.dart`: `from==to⇒true`, to-minute exclusive, cross-midnight; comment tying to the Kotlin canonical.

## 5. Dart alignment (C5)
`schedule_utils.dart:12-23` → canonical (`from==to⇒true`; half-open; cross-midnight `>=from || <to`); update doc. `active_profile_provider.dart:26-33` → picks up new semantics + add `isEnabled` interval filter (refinement #2). UI impact: `from==to` profiles now show active all-day (was never) — note in commit.

## 6. Commit sequence (compiles + green at each step; no enforcement gap)
- **C1** `Feat: BlockPolicyEvaluator + isProfileActiveNow canonico + test (ARCH-01/CR-02)` — new evaluator/types/tests, NO call-site change.
- **C2** `Fix: 3 path accessibility via BlockPolicyEvaluator (parity)` — rewire checkApp/Website/InAppContent; `isProfileActiveNow` becomes a thin Android wrapper delegating to the evaluator. Behavior identical (a11y was reference).
- **C3** `Fix: backup LockRunnable applica focus+wifi via evaluator (CR-01/CR-03)` — shared wifi helper, profileWifis+intervals in loadProfiles, focusShouldBlock, onFocusBlock; delete LockRunnable.isProfileActiveNow.
- **C4** `Fix: bypass sezioni in-app scoped section:<wireId> (CR-07)` — section show passes blockedDomain scope; regression test.
- **C5** `Fix: schedule_utils isNowInRange canonico + filtro intervalli isEnabled (CR-06)` — Dart alignment + tests.

## 7. Risks to flag in commits/report
R1 backup `to`-minute → half-open (≤1 min narrowing, only when a11y dead, matches a11y). R2 `from==to⇒24h` everywhere (user-visible: backup was 1-min, Dart was never). R3 no commit removes a live block before its replacement (C1 inert, C2 identical, C3 only adds backup enforcement, C4 fixes a broken bypass, C5 Dart/UI). R4 `bypassReasonFor` non-defaulted so omission = compile error. R5 wifi helper extracted (refinement #1), not copied.
