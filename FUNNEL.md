# Funnel measurement — the privacy-safe model

Koru's promise is **no telemetry, nothing leaves the device** (see the Privacy
section of the [README](README.md)). That has to stay true even once Koru Pro
ships. So we measure the conversion funnel **without any custom event sending**:

- **Aggregate cohort metrics** (installs, retention, uninstalls, purchases,
  refunds) come from **Google Play Console** and **Play Billing** — Google
  already collects these for any app on Play; we add nothing.
- **Per-step milestones** used for QA / debugging are stored **locally only**
  (Hive / Drift) and are read on-device via `adb` — they are never transmitted.

Nothing here opens a socket. The only `INTERNET` permission in the manifest is
transitive from plugins; Koru itself sends no funnel data.

## The funnel

| Step | Where it is measured | Notes |
| --- | --- | --- |
| Install | Play Console (acquisitions) + local `FIRST_INSTALL_TIMESTAMP` | local mark is QA-only |
| Accessibility granted | local `ACCESSIBILITY_GRANTED_AT` | first time the service is observed enabled |
| First profile created | *not tracked yet* | see "Gaps" below |
| First block triggered (activation) | Drift: `MIN(block_sessions.timestamp)` | also `restricted_access_events.timestamp` |
| Paywall view → purchase | Play Billing (when Koru Pro ships) | no custom events |

## Local milestones (Hive, write-once)

Owned by `lib/core/diagnostics/funnel_milestones.dart` (`FunnelMilestones`).
Each timestamp is written **once** at its event and never overwritten:

- `FIRST_INSTALL_TIMESTAMP` — set in `main()` bootstrap.
- `ACCESSIBILITY_GRANTED_AT` — set the first time `accessibilityHealthProvider`
  observes the service enabled.

Inspect them on a connected device:

```sh
# Milestones are logged to the BlackBox when first set (tag FUNNEL):
adb pull /sdcard/Android/data/com.dev.koru/files/koru_blackbox.log
# or call FunnelMilestones.dumpToBlackBox(hive) from a dev build, then pull.
```

## Derived from Drift (no extra storage)

- **First block / activation:** `SELECT MIN(timestamp) FROM block_sessions`.
- **Per-app usage / blocks over time:** existing stats queries.

These live in the relational DB already, so we do not duplicate them as Hive
milestones.

## Gaps / next steps

- **`firstProfileCreatedAt` is not captured.** The `Profiles` table has no
  `createdAt` column, and profiles are also created from onboarding presets
  (not only by the user). When needed, either add a write-once Hive mark at
  `ProfileRepository.createProfile` (user-initiated only) or add a Drift column
  (migration + native schema contract update). For activation, prefer the
  `block_sessions` signal above — a profile that never triggers a block is not
  really activation.
- **Conversion rate** (the ~2–3% expected) is computed post-launch from Play
  Console installs vs Play Billing purchases — there is no in-app counter to
  build, by design.
