# Koru Launcher Battery Investigation — Root-Cause Report

> Point-in-time analysis (2026-06-15). Multi-agent investigation: 14 candidate drains
> found, 9 stood up to adversarial verification, 8 confirmed to fire while the launcher
> is the idle foreground app. Historical artifact, not a living spec.

## 1. Executive Summary

Yes — Koru measurably drains more battery than a normal launcher at rest, but the cause is **CPU wakeups, not rendering, sensors, or wakelocks**. The single biggest contributor is the **`LockForegroundService` backup poll loop (`LockRunnable`)**, which wakes a daemon thread and fires a cross-process `UsageStats` binder query **every 5 seconds, 24/7, whenever the screen is on** — including while the user just stares at the clock — and immediately throws the result away because Koru-as-launcher is its own skip package. Everything else is comparatively minor: a per-second focus-session tick that reaches Dart, an unused-but-expensive accessibility flag, and a chatty battery broadcast receiver. There is **no wakelock, no continuous frame rendering, and no wifi/location/sensor scanning** on the idle home screen — an idle Koru home screen is close to zero-cost except for the 5s poll.

The fixes are low-risk and do **not** weaken blocking enforcement: the backup poller is documented to do nothing while the accessibility service is alive, so gating its work behind `instance == null` removes the waste without touching the primary event-driven enforcement path.

---

## 2. Ranked Root Causes (highest battery impact first)

### #1 — `LockRunnable` runs a wasted UsageStats query every 5s while idle on the launcher — **MEDIUM**
*(dimension: polling-sweeps / launcher-route-overhead — same loop, two findings)*

**Mechanism.** `LockForegroundService` is an always-on FGS started in the common case (any configured limit or enabled profile). Its daemon `LockRunnable.run()` is an infinite `while(isRunning)` loop. While the screen is interactive **and** `KoruAccessibilityService.instance != null` (the normal launcher-idle state), it sleeps 5000ms then calls `checkAndBlock()`. `checkAndBlock()` calls `ForegroundDetector.detect(context, 30_000)` **FIRST** — an unconditional `UsageStatsManager.queryEvents` binder round-trip into `system_server` plus a full iteration of every event in the window — and only **after** that hits the `skipPackages` / `instance != null` early-return. Because Koru is the default launcher, the foreground package equals `context.packageName` (a skip package), so the loop returns having accomplished nothing. ~720 wasted ticks/hour, 24/7 while the screen is on.

**Evidence.**
- `android/.../service/LockRunnable.kt:100-135` — loop + adaptive 5s sleep when a11y alive (`:130-134`)
- `LockRunnable.kt:115` — `checkAndBlock()` every interactive tick
- `LockRunnable.kt:186` — `ForegroundDetector.detect()` runs **before** any gate
- `LockRunnable.kt:206-221` — `skipPackages` / `instance != null` early-return **after** the query
- `LockRunnable.kt:74-84` — `context.packageName` is in `skipPackages` (launcher self skipped)
- `ForegroundDetector.kt:38-72` — `detect()` = `queryEvents` + full `while(hasNextEvent)` iteration, no caching
- `LockForegroundService.kt:188,326-329` — daemon thread; `MainActivity.kt:140-167` — FGS auto-starts whenever any limit/profile exists

**Why it's worse/needless on the launcher.** Koru-as-default-launcher means the user returns to an always-foreground Koru screen between every app, so the device spends far more wall-time in the screen-on/idle state where this poll fires — and in that exact state the query is 100% wasted (the result is the launcher itself, which is skipped). It is the dominant non-zero CPU consumer keeping the Koru process group from reaching a normal launcher's ~0 idle.

**Corrected impact: MEDIUM** — high fixed frequency (720/h, steady) × low per-tick cost (single-digit-ms binder query), fully wasted in this state. A relentless trickle, not a spike.

**Fix (no enforcement risk).** Move the `if (KoruAccessibilityService.instance != null) return` check to the **top** of `checkAndBlock()`, before `ForegroundDetector.detect()`. The backup loop exists *only* to cover `instance == null` (a11y killed/crashed); when a11y is alive it already intentionally does nothing (`LockRunnable.kt:218-221`). Gating the query behind liveness therefore cannot weaken the dead-a11y path, which keeps its 300ms reactivity. Optionally also stretch the interactive-with-a11y-alive sleep from 5s to 15-30s (it is only a liveness heartbeat in that state). The only cost is a slightly longer worst-case latency to *notice* a11y died (bounded, acceptable for a backup). **Verified safe:** the screen-off bypass-revoke edge-detect runs in `run()` before `checkAndBlock()` (`:109-113`) and is unaffected; `lastBypassedForegroundPkg` is already null while a11y is alive by design.

---

### #2 — 1s `QUICK_BLOCK_TICK` fans out to 4 Dart subscribers every second during a focus/pomodoro session — **MEDIUM**
*(dimension: flutter-ui-churn)*

**Mechanism.** Native `QuickBlockManager` uses `CountDownTimer(durationMs, 1000)` and calls `sendTickEvent()` every second for the entire focus/pomodoro duration, pushing a `QUICK_BLOCK_TICK` over `EventChannel com.koru/service_events`. `QuickBlockManager` runs in the **main process** (no `android:process` override), the same process as the live FlutterEngine, so while Koru's launcher is foreground the ticks **do** reach the Dart isolate. The single broadcast upstream wakes the isolate, `jsonDecode`s the payload, and dispatches to the always-live listeners. This is the **only continuous CPU-waking vector that reaches Dart** while the launcher sits idle.

**Correction to the finding:** there are **4** live subscribers at idle, not 3 — the finding omitted `packageEventsRefresherProvider` (early-returns each tick). The four are `blockingEventsRefresher`, `achievementEvaluator`, `packageEventsRefresher` (all root-watched in `app.dart`), and `openAppsCount` (launcher badge). `quickBlockTickProvider` is correctly excluded (autoDispose, only alive while `/focus` is mounted).

**Evidence.**
- `android/.../service/QuickBlockManager.kt:149` — `CountDownTimer(durationMs, 1000)`; `:150-152` `onTick → sendTickEvent`; `:274-285` emits to `ServiceEventChannel`
- `LockForegroundService.kt:43` — instantiated in main process; `AndroidManifest.xml:98-105` — no `android:process`
- `lib/platform/service_event_channel.dart:136-156` — single upstream `jsonDecode` + broadcast fan-out
- `lib/presentation/providers/events_refresher.dart:136` (blocking), `:238/241-242` (package, early-returns)
- `lib/presentation/providers/achievement_evaluator.dart:24,59-66`; `lib/presentation/providers/open_apps_count_provider.dart:39-44`
- `app.dart:24,25,27` — root-watched always-on providers

**Why it's worse/needless on the launcher.** The launcher renders no countdown (only `/focus` does), so a 1Hz push is pure waste when the launcher is foreground. Per-tick work is cheap and **frame-free** (all four consumers either early-return or only act on the `isActive` true→false edge — no DB query, no frame on intermediate ticks), but it is a forced isolate wakeup + `jsonDecode` + 4 closure dispatches every second for the full session (~1500 wakeups for a 25-min pomodoro). Zero cost when no session is active.

**Corrected impact: MEDIUM** — only fires during an active focus/quick-block session, but at 1Hz with a guaranteed isolate wakeup it is the heaviest Dart-side idle vector when a session runs.

**Fix (no enforcement risk).** The tick is purely a UI/stats signal — cross-process blocking is driven by `QuickBlockStore` (disk snapshot) + the `ACTION_RELOAD_PROFILES` broadcast (`QuickBlockManager.kt:262-272`), not by the tick, and the `:accessibility` process never consumes it. Prefer **Option 2**: emit a dedicated `QUICK_BLOCK_FINISHED` edge event on `onFinish`/phase-end, and subscribe the two edge-only consumers (`blockingEventsRefresher`, `achievementEvaluator`) to that instead of parsing every 1s tick. Leave the 1Hz tick only for the route-scoped autoDispose `quickBlockTickProvider` that actually renders the `/focus` seconds display. This removes the per-second dispatches whenever `/focus` is not on screen (the idle-launcher case). Option 1 (native-suppress when no countdown UI mounted) is weaker — native lacks a signal for whether `/focus` is mounted without an extra round-trip.

---

### #3 — `flagRetrieveInteractiveWindows` forces an unused cross-window snapshot on every launcher redraw — **LOW**
*(dimension: launcher-route-overhead)*

**Mechanism.** `accessibility_service_config.xml` sets `flagRetrieveInteractiveWindows`, which makes `system_server` compute and IPC the **full interactive-window list** to this process on every `TYPE_WINDOWS_CHANGED`. Window-level events are **not** package-gated (`packageNames` filtering only covers `TYPE_WINDOW_STATE_CHANGED`), so Koru's own launcher redraws — the clock's minute-boundary `setState`, the battery-icon update — each produce `TYPE_WINDOW_CONTENT_CHANGED`/`TYPE_WINDOWS_CHANGED` that cross the binder into `onAccessibilityEvent`. **Decisive finding:** a grep over the entire Kotlin tree for `getWindows()`/`.windows`/`windowsOnAllDisplays` returns **zero callers** — all detection uses `rootInActiveWindow`, which does **not** require this flag. The forced snapshot is pure waste.

**Evidence.**
- `android/app/src/main/res/xml/accessibility_service_config.xml:28` — `accessibilityFlags="flagRetrieveInteractiveWindows|flagReportViewIds"`
- Grep: **0** callers of `getWindows()/.windows/windowsOnAllDisplays`; all node access via `rootInActiveWindow` (`KoruAccessibilityService.kt:892,1009`)
- `WatchedPackageCalculator.kt:10-11,53-54` — launcher+self always in watched set; window-churn events bypass `packageNames` filter
- `circle_clock_widget.dart:25-52` (minute-boundary `setState`), `:66,105-119` (battery rebuild) — sources of idle redraws

**Correction to the finding's emphasis.** The in-process prologue cost is **overstated** — for these window-churn event types the handlers short-circuit cheaply: `LauncherRecentsGate.handleEvent` returns immediately (`:161`, not `TYPE_WINDOW_STATE_CHANGED`), `StrictModeEnforcer.handleEvent` returns when `mask==0` (strict off, the common case), and the expensive bypass-revoke UsageStats query does **not** run at idle (`lastBypassedActiveForeground` null). The real recurring cost is the `system_server` interactive-windows snapshot + binder delivery forced by the unused flag, not the Dart-side handler.

**Why it's worse/needless on the launcher.** Strictly extra vs a stock launcher: Koru's own compositions originate the window churn while it is foreground, and each redraw forces a snapshot nothing reads. But at a literal idle home screen the trigger rate is low (~1/min clock + a few/hour battery), so the absolute delta is small; it edges up only when the user repeatedly bounces app↔launcher.

**Corrected impact: LOW** — most-expensive single a11y flag, but low idle event rate ⇒ small absolute battery delta.

**Fix (no enforcement risk).** Remove **only** `flagRetrieveInteractiveWindows` from the config string; **keep `flagReportViewIds`** — it is genuinely consumed by the Instagram/YouTube/browser detectors (`InstagramDetector.kt:57`, `YouTubeDetector.kt:61`, browser URL detection via `viewIdResourceName`). Zero enforcement risk: grep proves nothing reads the windows list; all detection uses `rootInActiveWindow`, which does not need the flag. The secondary idea (dynamically toggle `typeViewScrolled`/`typeWindowContentChanged` onto `serviceInfo.eventTypes` only inside browser/in-app/recents sessions, mirroring the existing `setClickEventsEnabled` pattern) is architecturally sound but **riskier** — those event types drive browser URL re-checks, focus/limit-started-while-inside re-evaluation, and recents open-apps sync, so they must be armed on the *first* window-state event into the relevant context before the user scrolls, or the first re-check is missed. Ship the flag removal now; treat the eventType-gating as a separate, test-covered change.

---

### #4 — Permanently-registered `ACTION_BATTERY_CHANGED` receiver wakes the process on every battery tick — **LOW**
*(dimensions: a11y-firehose / wifi-location-sensors — same receiver, two findings)*

**Mechanism.** The launcher clock (`CircleClockWidget`) watches `batteryLevelProvider`/`isChargingProvider`, derived from `batteryStateProvider` — a **non-autoDispose** `StreamProvider`. Subscribing it triggers `BatteryEventChannel.onListen → registerReceiver(ACTION_BATTERY_CHANGED)` on `applicationContext`. Because the provider never auto-disposes and the clock is always mounted on the home screen, the receiver stays registered for the whole process lifetime. Each broadcast wakes the main-thread loop, parses ~4 intent extras, marshals a map over the EventChannel into Dart. Registration is in the **main process** (warm FlutterEngine via `KoruEngineManager`); there is no manifest-registered duplicate and **no wakelock**.

**Evidence.**
- `lib/presentation/providers/battery_provider.dart:29-38` — plain non-autoDispose `StreamProvider`; not in `_koruDataProviders` resume-invalidation list (registers exactly once, no churn)
- `circle_clock_widget.dart:66-67` watches battery; `launcher_home_screen.dart:207` mounts the clock unconditionally
- `BatteryEventChannel.kt:33-54` — `registerReceiver` on `applicationContext`; `:56-66` — `onCancel` unregister (never fires here); `:68-84` — `emit()` has **no** last-value cache
- `KoruEngineManager.kt:92-97` — registered on the main-process engine; `AndroidManifest.xml` — no duplicate receiver, no wakelock

**Correction to the finding's magnitude.** The "several to tens of times per minute" framing is overstated for the **not-charging, screen-on idle** case: the framework only re-broadcasts when a tracked field changes beyond a threshold, so on an idle, discharging device level/voltage/temp are nearly flat ⇒ a few/min at most. The "tens per minute" peak occurs only **while charging** — where the device is on external power and battery drain is moot. Also, redundant ticks do **not** rebuild the widget: the derived providers produce `==`-equal `AsyncData` and Riverpod suppresses the rebuild, so no frame is rendered for temperature/voltage-only ticks. Per-redundant-tick cost = one already-awake main-loop message + EventChannel marshal + two trivial provider recomputes.

**Why it's worse/needless on the launcher.** Launcher-specific delta vs a stock launcher: the receiver is registered exactly while Koru's home screen is foreground, and the process is guaranteed alive so every broadcast is actually delivered. But it holds no wakelock, schedules no alarms, and does work only when the system would already deliver a broadcast to a foreground process — it cannot prevent doze (screen is on by definition).

**Corrected impact: LOW** — real, correctly-traced, launcher-specific, but tiny energy delta.

**Fix (no enforcement risk — pure launcher UI, touches no blocking logic).** **Option A (minimal):** in `BatteryEventChannel.emit()`, cache last `{pct, charging}` and early-return when unchanged — removes the EventChannel hop + Dart recompute for redundant ticks. Preserve the initial sticky emit (`:53`) and seed the cache with a sentinel so the first value always fires. **Option B (durable, recommended):** drop the hot-path receiver entirely and read `BatteryManager.getIntProperty(BATTERY_PROPERTY_CAPACITY)` + `isCharging` on the existing per-minute clock tick — the clock already repaints once per minute, so matching battery cadence to that removes the high-frequency wakeup altogether. Avoid the "make `batteryStateProvider` autoDispose" fix — it does nothing for the reported scenario and adds register/unregister churn on every home↔drawer transition.

---

### #5 — 5s detect() cost is doubled by a 1-hour fallback re-query precisely in the idle-launcher dwell — **LOW**
*(dimension: polling-sweeps — a sub-effect of #1)*

**Mechanism.** `ForegroundDetector.detect()` runs `detectInternal` with a 30s lookback; if that returns null it retries with a **1-hour** lookback (`FALLBACK_LOOKBACK_MS = 3_600_000`). Sitting motionless on the launcher for >30s means Koru's own `ACTIVITY_RESUMED` has aged out of the 30s window and no other resume fires, so `detectInternal(30s)` returns null on **every** tick ⇒ the 1h fallback fires every 5s, iterating up to an hour of `UsageEvents` instead of 30s, only to find the launcher (skipped) and discard it. The idle-launcher dwell is *exactly* the case that selects the expensive branch.

**Evidence.**
- `ForegroundDetector.kt:25-36` — `detect → detectInternal(30s)`; on null, `detectInternal(1h)`; `:21-22` — `DEFAULT_LOOKBACK_MS=30s`, `FALLBACK_LOOKBACK_MS=1h`
- Called from `LockRunnable.kt:186` on every 5s tick

**Corrected impact: LOW** — a binder IPC + cursor scan, not rendering or node-tree traversal; on a quiet device the extra rows iterated in 1h are typically tens.

**Fix (CAUTION — naive version breaks enforcement).** Do **not** add a blanket `allowBootFallback=false`: the single call site (`LockRunnable.kt:186`) is shared by both the 5s tick (a11y alive) and the 300ms tick (a11y **dead** = backup actively enforcing). In backup-active mode the 1h fallback is **load-bearing** — if a blocked app has been foreground >30s (e.g. a bypass just expired with no new resume event), its `ACTIVITY_RESUMED` has aged out and without the wider window the backup goes blind. **Safe fix:** this branch is fully subsumed by fix #1 — once the query is gated behind a11y-liveness, it stops firing at idle entirely.

---

## 3. Checked and Clean (investigated, NOT a problem)

- **In-app content detectors (Instagram/YouTube) + website detector at idle** — confirmed **gated away** from the launcher. Detector dispatch (`KoruAccessibilityService.kt:984-1000`) sits after the skip-return (`:962-969`); when Koru's launcher is foreground `pkg == packageName` returns before any node walk. Node walks are depth-capped at `MAX_DEPTH=20`. *(Note: `MAX_SCAN_NODES` cited in one finding does not exist.)*
- **`StrictModeEnforcer` / `LauncherRecentsGate` / `OpenAppsTracker.noteForeground` before the skip-return** — refuted; short-circuit cheaply on window-churn events.
- **Watched-set including launcher+self causing per-event wakeups** — refuted; marginal cost is the cheap short-circuiting prologue under #3.
- **Picker sub-screens spinning a `CircularProgressIndicator`** — refuted; not the idle home screen.
- **Full-screen `systemGestureExclusionRect` re-posted on every launcher resume** — refuted; negligible, correctly route-scoped via `RouteAware`.
- **`WifiManager` SSID read** — confirmed **NOT** a drain: uses deprecated `connectionInfo` (no active scan, no location), gated off the launcher. **No wifi/location/sensor access occurs on the idle home screen.**
- **No wakelock anywhere on these paths** — old `PARTIAL_WAKE_LOCK` removed (`LockForegroundService.kt:79-92`); nothing re-acquires it. No continuous frame rendering on the idle home screen (clock repaints once per minute).

---

## 4. Prioritized Fix Plan

| # | Change | Tag | Expected battery benefit | Risk |
|---|--------|-----|--------------------------|------|
| 1 | **Move `if (KoruAccessibilityService.instance != null) return` to the TOP of `checkAndBlock()`**, before `ForegroundDetector.detect()` (`LockRunnable.kt`). | **[quick-win]** | **Highest.** ~720 wasted binder queries/hour → zero whenever a11y is healthy. Brings idle home screen near a normal launcher's ~0. | **None.** Backup does nothing while a11y alive (`:218-221`); dead-a11y 300ms path untouched. |
| 2 | *(Optional, with #1)* Stretch the interactive + a11y-alive sleep from 5s to **15-30s** (`LockRunnable.kt:130-134`). | **[quick-win]** | Further cuts thread wakeups in the rare window where #1 still ticks. | **Negligible.** Slightly longer latency to notice a11y died; bounded. |
| 3 | **Emit a `QUICK_BLOCK_FINISHED` edge event**; subscribe `blockingEventsRefresher` + `achievementEvaluator` to it instead of parsing every 1s `QUICK_BLOCK_TICK`. | **[larger]** | **Medium** during focus/pomodoro sessions; zero when no session runs. | **None.** Tick is UI/stats only; blocking driven by `QuickBlockStore` + `ACTION_RELOAD_PROFILES`. |
| 4 | **Remove `flagRetrieveInteractiveWindows`** from `accessibility_service_config.xml:28` — **keep `flagReportViewIds`**. | **[quick-win]** | **Low.** Stops unused `system_server` window snapshot on every launcher redraw / app↔launcher bounce. | **None.** Grep proves zero readers; preserve `flagReportViewIds`. |
| 5 | **Coalesce `ACTION_BATTERY_CHANGED`** — cache last `{pct,charging}` in `emit()` (Option A); or read `BatteryManager` on the per-minute clock tick (Option B). | **[quick-win]** (A) | **Low.** Removes redundant EventChannel hops (most gain while charging). | **None** — pure launcher UI. |
| 6 | *(Deferred)* Dynamically toggle `typeViewScrolled`/`typeWindowContentChanged` onto `serviceInfo.eventTypes` only inside browser/in-app/recents sessions. | **[larger]** | Low-medium — shrinks idle event surface to ~`typeWindowStateChanged`. | **Medium — needs tests.** Must arm on first window-state event before scroll, or first re-check missed. |

**Recommended order:** ship #1 (+#2), #4, and #5-Option-A as immediate quick-wins — together they remove the entire steady-state idle-launcher CPU cost with zero enforcement risk. Follow with #3, then optionally #5-Option-B. Defer #6 behind tests.

**Bottom line:** the idle Koru home screen should cost ~0 CPU; today it doesn't, almost entirely because of **fix #1**. That single change is the highest-leverage battery improvement and carries no risk to blocking correctness.
