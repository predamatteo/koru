# Koru vs. Stock Launcher — Real-Battery A/B Protocol (OnePlus 8T, OxygenOS 15)

> **Type: RUNBOOK / one-evening procedure — NOT a living spec.**
> Date: 2026-06-15. Device: OnePlus 8T `6d05b840`, OxygenOS / Android 15 (targetSdk 35).
> Koru `com.dev.koru` is currently the default launcher; a fixed build is installed.
> This document is point-in-time. Re-verify every `adb` command if the build or ROM changes.

---

## 1. TL;DR

**Question:** Does running Koru (`com.dev.koru`) as the default launcher drain *more real battery* than the OnePlus stock launcher (`com.android.launcher`), and by how much?

**Headline metric: SCREEN-OFF STANDBY.** We measure the hardware coulomb counter (`cmd battery get counter`, µAh) drop across **identical, machine-driven STANDBY windows** — phone **physically unplugged**, **screen OFF**, **airplane mode ON**, **Doze in its NORMAL state**, in an **interleaved A-B-A-B** design. Standby is the **only** regime where the launcher's small background tax (FGS + AccessibilityService + NotificationListener) accumulates above the fuel gauge's quantization. Each window is **90-120 min** so that a ~1-3 mAh/h tax sums to **2-6 mAh** against a tiny idle baseline — clearing the ±2 mAh floor.

**Active screen-ON is DIAGNOSTIC ONLY, not a headline.** Two reasons, both fatal to it as an energy number: (1) the expected compute delta (1-3 mAh per several minutes) is **smaller than one 1000 µAh quantization step** and is buried under ~8-12 mAh/min of screen drain; (2) the two launchers render **different pixels** (Koru is minimalist/dark; OplusLauncher draws a full wallpaper + icon grid), so the OLED **panel** power differs between arms by potentially *more* than the CPU delta we are hunting. Screen-ON cannot separate compute cost from panel cost. We still run a scripted active workload to confirm the **sign** and the **`system_server` delta** the prior CPU work identified, but we report it with that caveat, never as "Koru costs X mAh while you use it."

**What we report:**
- **Standby delta (PRIMARY):** `mean ± 95% CI` of paired (Koru − stock) drain, normalized to **mAh per hour**.
- **Active delta (DIAGNOSTIC):** paired (Koru − stock) drain per fixed run **and** the **UID-1000 (system_server) A−B difference** from batterystats — sign/where only.

**Expected outcome (given priors):** SMALL, most likely a **bounded near-null**. No runaway CPU loop; no Koru wakelock; the 5 s poll was already fixed (BlockingThread 4→1 jiffy); Koru's own-process CPU is identical old-vs-new, the only system-level saving being `system_server` (~10% less, from dropping `flagRetrieveInteractiveWindows`). The honest expected result: **standby delta a few mAh/h or less, CI likely including 0.** **A tightly-bounded "no detectable delta, bounded by ±Z mAh/h" is a valid, correct answer.** Do not torture the data to manufacture a delta.

---

## 2. Which method & why

| Method | Role | Why |
|---|---|---|
| **M2 — Screen-OFF standby ΔµAh** (90-120 min, airplane, **normal Doze**, paired ABAB) | **HEADLINE** | The only clean regime. Screen (the dominant masker) is OFF; the panel-pixel confound disappears entirely; the launcher's FGS+a11y+listener tax accumulates over 90-120 min to clear the ±2 mAh quantization. Trivial to automate (phone just sleeps). |
| **M1 — Screen-ON scripted-identical workload ΔµAh** (paired ABAB) | **DIAGNOSTIC ONLY** | Captures the *sign* of Koru's induced `system_server` cost during active use. **Demoted** because (a) the expected effect is below one quantization step under a large screen masker, and (b) the two launchers emit different pixels, so panel power, not compute, may dominate the delta. Never a headline number. |
| **M3 — batterystats per-UID, system_server (UID 1000) A−B delta** | **SANITY ONLY** | Free piggyback on M1. Confirms sign and *where* (cpu vs wakelock vs screen). On this device the model reads ~30% low (1446 mAh computed vs 1935-2070 actual) and UID 1000 carries a negative `reattributed=-62.9` fudge that mixes every app's system cost. So we report only the **UID-1000 A−B difference** within the controlled ABAB — **never** a "Koru-UID + UID-1000 sum" (that sum is not an isolation of Koru). |
| M4 — battery % drop | Skipped except a 30 s no-stuck-wakelock smoke test. 1% ≈ 45 mAh — far coarser than a window. |

**Why the coulomb counter and not sysfs / current_now / batterystats mAh:**
- `/sys/class/power_supply/battery/*` is **PERMISSION DENIED** to the non-root adb shell (SELinux). The only root-free real-energy path is framework `BatteryManager`: **`cmd battery get counter`** (µAh).
- `current_now` is not surfaced; OPLUS "Battery current" uses an internal sign convention and reads **negative while charging** (verified: −71, −178 with `USB powered: true`, `status: 2`) — **never** infer discharge direction from it.
- batterystats mAh is a **power-profile model** (no per-UID ODPM rails on this pm8150b) — diagnostic only.

**Quantization (verified, this is the whole reason for the design):** `cmd battery get counter` is quantized to **1000 µAh steps**. Five back-to-back reads all returned `2336000`; consecutive plugged reads stepped `2334000 → 2336000 → 2338000` in exact 2000 µAh increments. So each endpoint is **±1 mAh**, and a single delta is **±2 mAh**. Averaging *n* pairs beats the **random** component down ~√n; it does **not** remove systematic bias. Therefore each measured window must drain **far more than 2 mAh** — which only the long standby window reliably does.

**Sign convention (verified):** the counter **rose** while charging (`2324000 → 2326000` over 30 s plugged). So while unplugged it **falls monotonically**, and **energy consumed = counter_start − counter_end** (µAh). mAh = µAh / 1000. If a delta ever comes out **≤ 0**, the cable was carrying power — discard.

**Runnability constraint:** WiFi-adb is unavailable (WiFi off) and the phone must be unplugged during the measured window. So every run is **self-driving on the device**: an on-device `sh` loop / sleep latches the start counter+timestamp to a file, runs the fixed workload (or just sleeps) for a fixed duration, latches the end counter+timestamp. You **unplug right after it starts** and **re-plug only after it ends**, then pull the file. **Charging must never overlap the measured window.**

---

## 3. Pre-flight setup

Run all of these **once** at the session start, phone **still plugged** (setup only — you unplug per run). The `settings put` recipes are intentionally absent: they fail with `SecurityException` (no `WRITE_SECURE_SETTINGS`) on this build; the matching steps are done by hand in the UI.

```powershell
$D = "6d05b840"

# --- 0. Identify device & confirm Koru is current default ---
adb -s $D shell cmd role get-role-holders android.app.role.HOME
#   expect: com.dev.koru
adb -s $D shell cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME
#   expect resolved: com.dev.koru/.MainActivity

# --- 1. Airplane mode ON for the WHOLE test (kills cellular/WiFi radio noise) ---
adb -s $D shell cmd connectivity airplane-mode enable
((adb -s $D shell cmd connectivity airplane-mode) | Out-String).Trim()
#   The no-arg form prints a BARE word: exactly "enabled" (or "disabled") — NOT a labeled line.
#   Assert with exact-equality, not -match:  $state -eq 'enabled'
#   (restore at end with: cmd connectivity airplane-mode disable)

# --- 2. batterystats: stop auto-reset on unplug, then reset cleanly ---
adb -s $D shell dumpsys batterystats enable no-auto-reset   # expect: Enabled: no-auto-reset
adb -s $D shell dumpsys batterystats --reset

# --- 3. Confirm Doze is in its NORMAL (enabled) state for BOTH deep and light. DO NOT disable it. ---
adb -s $D shell dumpsys deviceidle enabled deep    # expect: 1
adb -s $D shell dumpsys deviceidle enabled light   # expect: 1
#   Koru is whitelisted (user,com.dev.koru,10942) and bucket 5/ACTIVE, so its FGS runs UNDER normal Doze.
#   Globally disabling Doze would inflate EVERY app + the radios and swamp the small Koru delta. Leave it alone.

# --- 4. 30-second smoke test: confirm NO stuck wakelock / gross runaway ---
adb -s $D shell dumpsys power | Select-String "mWakefulness|Wake Locks|PARTIAL_WAKE"
adb -s $D shell dumpsys activity services com.dev.koru | Select-String "ServiceRecord"
#   Under A (Koru default) you should see THREE Koru ServiceRecords (see neutralization note in Section 4),
#   but NO partial wakelock held by com.dev.koru.
```

**Manual UI steps (adb is BLOCKED for these on this build — `settings put` → SecurityException):**

1. **Brightness:** turn **OFF auto-brightness** and set a **fixed slider position**, identical for every run. Read-only check: `adb -s $D shell settings get system screen_brightness_mode` reads `1` (auto) until you flip it off in the UI.
2. **Screen timeout:** set to **30 min** so the screen survives an active run without fighting a short timeout. Read-only check after: `settings get system screen_off_timeout` = `1800000`.
3. **Do Not Disturb: ON.** **Location: OFF.** **Bluetooth: OFF.** WiFi already off (airplane). DND-on + airplane-on drives the local notification rate toward ~0 so the NotificationListener has nothing to wake on (it would otherwise fire asymmetrically in A and not B).
4. Settle background churn before the session:

```powershell
adb -s $D shell am kill-all
```

> **OxygenOS battery-optimization scope (read this — it bounds the ANSWER):** `com.dev.koru` is in the deviceidle whitelist (`user,com.dev.koru,10942`), standby bucket **5 (ACTIVE)**, `RUN_ANY_IN_BACKGROUND = allow`. Good for **test stability** (the OS won't kill Koru's services mid-run) but it means we measure Koru's cost **without OEM throttling**. **Generalizability caveat to state in the result:** this answers *"Koru's cost when whitelisted,"* not *"Koru's cost for a user who never whitelisted it"* (who would see it throttled, hence cheaper). Do not over-claim.

> **Doze handling — pick ONE and apply to A *and* B identically, never one-sided:**
> - **Standby (M2, headline):** **leave Doze NORMAL on both.** Koru's whitelist guarantees its FGS survives anyway, and you are measuring the real product's standby tax. (If you specifically want the deep-doze figure, `dumpsys deviceidle force-idle deep` on **both** arms identically and restore with `unforce`.) **Never** `dumpsys deviceidle disable` — that contaminates the baseline and leaves the phone in a non-default power state.
> - **Active (M1, diagnostic):** keep Doze NORMAL (you're interacting). Do not force-idle.

---

## 4. Measurement procedure

### Launcher switching (both directions, verified) + FULL Koru neutralization for B

Switching the home role is necessary but **not sufficient** for a clean stock (B) baseline. **Koru runs THREE services** that all stay alive even when it is not the active launcher, and two of them auto-rebind after a force-stop:

- `KoruAccessibilityService`
- `LockForegroundService` (FGS)
- `KoruNotificationListenerService`

`am force-stop` kills the process for a moment, but an **AccessibilityService** and a **NotificationListenerService** are **auto-rebound by the system within seconds** unless their bindings are disabled. If B silently carries any of them, the delta **artifactually collapses toward 0** — the exact failure mode this protocol exists to avoid. So B neutralization is a multi-step, **re-verified-after-settle** procedure.

```powershell
$D = "6d05b840"

# ============ SWITCH TO STOCK (condition B) AND FULLY NEUTRALIZE KORU ============

# 1. Set the stock launcher as home (full component — the bare form NPEs; see note below).
$r = ((adb -s $D shell cmd package set-home-activity com.android.launcher/.Launcher) | Out-String).Trim()
if ($r -notmatch 'Success') { throw "set-home-activity (stock) did not return Success: $r" }
adb -s $D shell input keyevent KEYCODE_HOME
$home = ((adb -s $D shell cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME) | Out-String)
#   MUST resolve com.android.launcher/.Launcher  (NEVER com.android.settings/.FallbackHome)

# 2. In the UI (Settings > Accessibility) toggle Koru's AccessibilityService OFF.
#    In the UI (Settings > Notifications > Notification access) toggle Koru's NotificationListener OFF.
#    (settings put secure enabled_accessibility_services / enabled_notification_listeners fail here — UI only.)

# 3. Deny background execution and force-stop.
adb -s $D shell cmd appops set com.dev.koru RUN_ANY_IN_BACKGROUND ignore
adb -s $D shell am force-stop com.dev.koru

# 4. SETTLE ~60 s, THEN re-check (rebind is DELAYED — a pre-run check alone is not enough).
#    Run this AFTER waiting; it must print NOTHING:
adb -s $D shell dumpsys activity services com.dev.koru | Select-String "ServiceRecord"
#    If ANY ServiceRecord reappears, B is contaminated -> the a11y / listener toggle did not take. Redo step 2.

# ============ SWITCH BACK TO KORU (condition A) — restore the real product ============

$r = ((adb -s $D shell cmd package set-home-activity com.dev.koru/.MainActivity) | Out-String).Trim()
if ($r -notmatch 'Success') { throw "set-home-activity (koru) did not return Success: $r" }
adb -s $D shell input keyevent KEYCODE_HOME
adb -s $D shell cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME
#   MUST resolve com.dev.koru/.MainActivity
adb -s $D shell cmd appops set com.dev.koru RUN_ANY_IN_BACKGROUND allow
# In the UI, re-enable BOTH Koru's AccessibilityService AND its NotificationListener so A is the genuine product.
# SETTLE ~60 s, then confirm the THREE services are back:
adb -s $D shell dumpsys activity services com.dev.koru | Select-String "ServiceRecord"
#   Expect three ServiceRecords (KoruAccessibilityService, LockForegroundService, KoruNotificationListenerService).
```

> **`set-home-activity` foot-gun (verified):** the **bare** form (no component) throws `NullPointerException ... runSetHomeActivity` and silently leaves the home role unchanged. **Always** pass the full component and assert the result equals `Success`, then re-verify with `resolve-activity`. The harness guards against an empty component.

> **HOME landing foot-gun (verified):** after `am force-stop com.dev.koru`, pressing HOME can briefly resolve to `com.android.settings/.FallbackHome` if the stock launcher isn't materialized yet. Always set + `resolve-activity`-verify the home holder **before** starting any workload; the active workload additionally asserts the foreground package mid-run and aborts if it ever lands on FallbackHome.

### Self-driving on-device workloads

Push these two scripts once (while plugged), then invoke via the harness.

**Active-use workload (M1, diagnostic)** — launcher-isolated. It exercises **only the launcher under test** (wake → open the app drawer → scroll → HOME), so it does **not** import a third-party app's variable cost into both arms. A neutral app is **deliberately avoided**: `am start ... Settings` cold-launches only the first time (`LaunchState: COLD, 808 ms`) and just re-fronts afterwards (`Activity ... brought to the front`, near-zero), making per-iteration cost depend on uncontrolled memory pressure. The launcher-only loop isolates the **launcher render cost** the priors flagged as the real driver. Coordinates are the OnePlus 8T drawer-swipe (full-height up-swipe from the home screen); adjust if the gesture differs.

```sh
# work_active.sh  ->  /data/local/tmp/work_active.sh
#!/system/bin/sh
DUR=${1:-600}                 # default 10 min; harness passes the duration
END=$(( $(date +%s) + DUR ))
i=0
while [ "$(date +%s)" -lt "$END" ]; do
  input keyevent KEYCODE_WAKEUP                 # keep the screen alive
  input keyevent KEYCODE_HOME                   # land on whichever launcher is default
  # mid-run guard: if HOME ever resolves to FallbackHome, abort loudly (writes a marker the harness checks)
  TOP=$(dumpsys activity activities | grep -m1 'topResumedActivity' )
  case "$TOP" in *FallbackHome*) echo "ABORT_FALLBACKHOME" > /data/local/tmp/work_abort.flag ; exit 7 ;; esac
  sleep 2
  input swipe 540 1900 540 300 200              # swipe up -> open the app drawer (the launcher renders it)
  sleep 2
  input swipe 540 1500 540 400 250              # scroll the drawer (launcher list re-render)
  sleep 1
  input swipe 540 400 540 1500 250              # scroll back
  sleep 1
  input keyevent KEYCODE_HOME                   # close drawer -> launcher home re-render
  sleep 2
  i=$(( i + 1 ))
done
echo "DONE $i" > /data/local/tmp/work_done.flag
```

**Standby workload (M2, headline)** — screen OFF, then a fixed sleep. The sleep keyevent is issued **first** and the harness confirms the screen actually went to sleep before it latches the start counter (otherwise the first read records `Awake` for a standby run).

```sh
# work_standby.sh  ->  /data/local/tmp/work_standby.sh
#!/system/bin/sh
input keyevent KEYCODE_SLEEP                    # screen OFF
DUR=${1:-5400}                                  # default 90 min; pass 7200 for 120
sleep $DUR
echo "DONE" > /data/local/tmp/work_done.flag
```

```powershell
# Push both once, while plugged:
adb -s $D push .\work_active.sh  /data/local/tmp/work_active.sh
adb -s $D push .\work_standby.sh /data/local/tmp/work_standby.sh
adb -s $D shell chmod 755 /data/local/tmp/work_active.sh /data/local/tmp/work_standby.sh
```

> The harness in `tools/battery_ab_session.ps1` also writes these scripts to the device on first run, so a manual push is optional.

### Run structure & N

- **M2 (standby, HEADLINE):** interleaved **A-B-A-B(-A-B)** → **≥4 windows = 2 pairs** (3 pairs if the evening allows). **90 min** per window (use 120 for more headroom). **Discard the first window** as settle. ~6-9 h wall-clock for 2-3 pairs — recharge into band between pairs.
- **M1 (active, DIAGNOSTIC):** interleaved **A-B-A-B…** → **≥4 pairs**. **10-15 min per run** (long enough that drain ≫ quantization; do not use 5 min). **Discard run 1** as warm-up.
- **Randomize** the starting condition (coin flip) so thermal rise and SOC fall hit both arms equally. Always **ABAB interleaved**, never AAA-then-BBB.
- **Tight SOC band ~10 points (e.g. 55-65%)** for all runs. Recharge into band **between pairs, never mid-pair**. **Reject any pair whose two members differ in mean SOC by > 8 points.**
- **Reject any pair whose two members differ in mean temperature by > 2 °C** (tight — a 1-3 mAh effect is thermally fragile).
- **Re-plug only to read/recharge**, never during a measured window.

### Per-run loop (operator actions)

1. Set the correct launcher (A or B); verify `resolve-activity`; **for B, after a 60 s settle, confirm zero Koru ServiceRecords**.
2. `am kill-all`; **quiescence gate**: confirm no pending jobs before latching — `adb -s $D shell dumpsys jobscheduler | Select-String "Pending"` should show an empty/zero pending queue; settle ~30-60 s.
3. **Physically unplug.**
4. Start the harness for this run. It guards that the device is unplugged, latches the start counter on-device, runs the on-device workload for the fixed duration, latches the end counter, and (after you re-plug) appends the CSV row.
5. When the harness reports done, **re-plug**; let it read the end counter and append.
6. Recharge into band if needed; go to the next run (alternating condition).

### At the very end — RESTORE the phone

```powershell
$D = "6d05b840"
adb -s $D shell cmd package set-home-activity com.dev.koru/.MainActivity        # Koru back as default
adb -s $D shell input keyevent KEYCODE_HOME
adb -s $D shell cmd appops set com.dev.koru RUN_ANY_IN_BACKGROUND allow
# Re-enable Koru AccessibilityService + NotificationListener in the UI (if disabled for B).
adb -s $D shell cmd connectivity airplane-mode disable                          # radios back on
adb -s $D shell dumpsys deviceidle unforce                                       # only if you used force-idle
adb -s $D shell dumpsys batterystats enable auto-reset                           # restore auto-reset
# Turn auto-brightness, DND, location, BT, screen timeout back to normal in the UI.
adb -s $D shell cmd role get-role-holders android.app.role.HOME                 # expect com.dev.koru
```

---

## 5. Runnable harness

The PowerShell harness is `C:\Users\preda\Desktop\MP\new_app\tools\battery_ab_session.ps1`. It is PowerShell 5.1-compatible (no `?:`/`??`), reads the verified `cmd battery get counter` (µAh), and appends one CSV row per run to `battery_runs.csv` next to the script. See the header comment in that file for usage. Key behaviors fixed from the draft:

- **Unplugged pre-guard AND post-guard.** Aborts before the run if `status: 2` (charging) / `status: 5` (full). Aborts **after** the run if `delta_uAh ≤ 0` (counter did not fall ⇒ the cable carried power ⇒ window void). Plug-detection uses battery **status** (2=charging, 5=full), more robust than greping `powered: true`.
- **Correct cast order.** `[int64](($raw).Trim())` — trim the **string**, then cast (adb on Windows emits CRLF; casting first then `.Trim()` on an int64 throws).
- **On-device timestamps.** Latches use `date +%s` evaluated **inside the device shell** — never PowerShell `Get-Date -UFormat %s` (which emits a locale decimal separator, a comma on this Italian-locale machine, breaking `[double]::Parse` and the echo).
- **NaN-safe thermal guard.** If a temperature read fails (`NaN`), the harness errors loudly instead of silently disabling the drift check (NaN comparisons are always false).
- **Standby screen-state ordering.** For standby it issues SLEEP and **confirms `mWakefulness` is Asleep/Dozing** before latching, so the CSV never records `Awake` for a standby window.
- **Single CSV schema, single writer.** One blocking code path, one fixed 17-column schema, one row appended after re-plug. No incompatible detached-vs-blocking rows; finish run N fully before starting N+1 (no concurrent `Add-Content`).
- **M3 (active only):** reads per-UID **estimated power** from `dumpsys batterystats` (the *default* dump's "Estimated power use (mAh)" block) — **not** `--usage`, which on this device is merely the `no-auto-reset` writer flag, not a per-UID selector. Records the raw `UID 1000` line so the analysis can take the **A−B difference**; does **not** sum Koru-UID+1000.

---

## 6. Interpreting results

### Compute paired differences (never group means)

Pair each **adjacent** A-B (or B-A).
- **Standby (M2, headline):** normalize to per hour — `mAh_per_h = delta_mAh × 3600 / duration_s` — then `d_i = (per-h Koru) − (per-h stock)`.
- **Active (M1, diagnostic):** `d_i = delta_mAh_Koru − delta_mAh_stock` for equal-duration runs (confirm `duration_s` matches; no further normalization).

Over the *n* kept pairs:
```
mean(d), SD(d), 95% CI = mean(d) ± t_{0.975, n-1} · SD(d)/√n
(small-n rule of thumb: mean(d) ± 2·SD(d)/√n)
```

### Decision rule (applied to the STANDBY headline)
- **CI entirely > 0** → Koru draws **more** real standby battery; report `mean(d)` mAh/h with its CI.
- **CI straddles 0** → **"No detectable standby delta, bounded by ±Z mAh/h"** (Z = CI half-width). **This is a valid, useful, expected answer.**

The **active** result is reported as a **directional, screen-confounded sanity note** alongside the **UID-1000 (system_server) A−B difference** — never as a standalone mAh-per-session headline.

### Noise floor (state it upfront)
Charge-counter quantization = **±1 mAh/endpoint = ±2 mAh/delta** (verified 1000 µAh steps). Therefore:
- A **single pair** is pure noise; never report one pair as the answer.
- Averaging *n* pairs beats the **random** component ~√n; it does **not** remove systematic bias.
- **Size each window so the absolute drop ≫ quantization.** A 90 min standby window drops well over 2 mAh even at a low idle baseline; a 10-15 min active run drains ~100-150 mAh (mid-brightness), making ±2 mAh ~1.5%. Five-minute active runs (~40-60 mAh) put a 1-3 mAh effect **below one step** — which is exactly why active is diagnostic-only.

### µAh → real-world impact
Battery ≈ **4500 mAh** (`Estimated battery capacity: 4500`). 1% ≈ **45 mAh**.
- **Standby:** `mean(d) = +X mAh/h` ⇒ `X/45 = X·0.022 %/h`. Example: +3 mAh/h → ~0.07 %/h → ~1.6% over a 24 h standby day. Bounded null → negligible.
- Put any active figure in context: most "using the phone" battery is **screen**, which is identical between launchers and **cancels by construction** here — so it is excluded from the headline by design.

### M3 cross-checks (sanity, not headline)
- Summed coulomb drain per active run should **roughly track** batterystats "actual drain."
- The interpretable system-server signal is the **UID-1000 difference (A − B)** within the ABAB, **not** its absolute value (UID 1000 carries every app's reattributed cost and a negative fudge term). It should **agree in sign** with the active coulomb delta even though the model runs ~30% low.
- **Sign disagreement, or a non-Koru/non-system UID dominating ⇒ background contamination; reject that run.**

---

## 7. Failure modes / honesty — when to NOT trust the result

Reject the run, the pair, or the whole comparison if any hold:

1. **Device was plugged during the window.** The harness pre-guard (status 2/5) aborts; the **post-guard** discards any run with `delta_uAh ≤ 0` (counter rose ⇒ charging). `cmd battery unplug` only fakes the *flag* — it does **not** stop real charging; always `cmd battery reset` after, and **physically unplug** to measure.
2. **B still carried Koru.** If `dumpsys activity services com.dev.koru` showed **any** ServiceRecord during a B run after the 60 s settle (a11y or NotificationListener not toggled off, or a rebind), B is contaminated and the delta collapses to ~0. Re-do that pair. (This is the single most common way to get a fake null.)
3. **Brightness varied** (auto-brightness left on, or different slider positions A vs B). Ambient-light variation dwarfs the launcher delta. Discard.
4. **Active screen-ON quoted as the headline.** Different launchers emit different pixels; the panel-power difference can exceed the compute delta. Active is diagnostic only.
5. **Temperature drift > 2 °C between pair-mates** (logged `start_temp_c`/`end_temp_c`). Reject the pair.
6. **SOC outside the 55-65% band**, or pair-mates differing in mean SOC by > 8 points. Gauge nonlinearity / voltage sag on this pm8150b (a modeled accumulator, not a true integrator) biases the delta. Recharge into band and redo.
7. **Doze inconsistent** — `disable`d globally, or `force-idle` on one arm only. The classic standby wrecker (order-of-magnitude error). Leave Doze **normal on both**; if forcing, force **both** and restore.
8. **A single A-B pair reported as the answer.** With ±2 mAh quantization, one pair is noise. Only an averaged CI over ≥2-3 standby pairs (≥4 active) counts.
9. **batterystats mAh quoted as ground truth.** It's a model (1446 vs 1935-2070 actual, ~30% low) hiding Koru's induced cost in UID 1000. Sign/where only; report the **UID-1000 A−B difference**, not a Koru+1000 sum.
10. **A non-Koru, non-system UID dominates M3** (a sync/notification fired in one arm) — background contamination; reject that run.
11. **AAA-then-BBB instead of interleaved.** Thermal rise and SOC fall then correlate with condition → fake delta. Always ABAB, randomized start.
12. **Curvature, not just trend, across a long block.** Interleaving balances the *linear* SOC/thermal drift but not curvature; with only 2-3 standby pairs there are too few degrees of freedom to detect it. Keep the SOC band tight and the block short, and treat a small monotonic drift as a reason to add a pair rather than to claim a delta.
13. **No quiescence gate.** A deferred sync firing in one arm injects tens of mAh. Confirm `dumpsys jobscheduler` shows no pending jobs and the top app is stable before latching.

**Honesty clause:** given the priors (no wakelock, poll already fixed 4→1 jiffy, no runaway loop, Koru's own CPU identical old-vs-new, only `system_server` saving), the **most likely correct outcome is a bounded near-null** — e.g. *"standby delta = +1.2 ± 1.8 mAh/h (CI includes 0); i.e. no standby battery cost detectable above ~±2 mAh/h. Active screen-ON is panel-confounded and not reported as a number; the system_server UID-1000 A−B difference was small and consistent in sign with the prior CPU finding."* **Report that bounded null as the answer.** Do not extend runs selectively, drop inconvenient pairs, switch metrics, or read the panel-confounded active number as a launcher compute cost in order to manufacture a positive delta. Also state the **generalizability caveat**: this is *Koru-when-whitelisted*; an un-whitelisted install would be throttled and cost less.
