# Security & enforcement — the honest threat model

Koru is a **mindful** blocker. Its job is to add **enough friction that an
impulse passes**, not to turn your phone into a vault. This document states
plainly what Koru's enforcement can and cannot do, so nobody buys, installs,
or trusts it under a false impression.

## Strict Mode is a deterrent, not an unbreakable lock

Strict Mode uses Android **Device Admin** plus **Accessibility-service window
interception** to make Settings, Recent apps, and Koru's own uninstall flow
harder to reach. It is **not** a kernel-level lock.

Concretely, Koru is a Device **Admin**, not a Device **Owner**. Android does
not let a regular Device Admin app refuse its own deactivation or truly
prevent its uninstall — that capability only exists in **Device Owner / DPC
mode**, which requires enterprise provisioning (QR code or `adb` on a
factory-reset device). So when you try to disable Strict Mode, Koru can show
the weekly backdoor-code prompt and a warning, **but if you confirm in the
system dialog, the disable proceeds.** The protection is friction by design.

A motivated user can always get past it, for example by:

- using `adb pm uninstall` or a computer,
- disabling the Accessibility service from system Settings,
- or removing Device Admin and then uninstalling normally.

That is acceptable: Strict Mode is meant to stop the *3-second craving*, not a
determined, calm decision to remove the app.

## Everything advanced rides on one Accessibility service

Strict Mode, in-app section blocking (Reels / Shorts / Stories), website /
URL blocking across browsers, and the Settings/Recents/uninstall interception
**all depend on the single `KoruAccessibilityService`**. If that permission is
turned off or revoked, those features stop working.

Android is **tightening when non-accessibility apps may use the Accessibility
API** (expected to roll out around 2026). Koru does **not** declare
`isAccessibilityTool` — it is a launcher + blocker, not an accessibility tool,
and claiming otherwise would be dishonest and against Play policy. The
trade-off is that Koru has **no durable defense against the OS revoking the
Accessibility permission**.

## What still works when Accessibility is gone

Koru also runs a **backup foreground service** that polls usage stats. If the
Accessibility service is disabled or revoked, enforcement **degrades
gracefully** rather than failing silently:

| Feature | Accessibility ON | Accessibility OFF/revoked |
| --- | --- | --- |
| Coarse app blocking (whole-app) | ✅ | ✅ (via usage-stats backup) |
| Daily limits / Focus / Quick Block | ✅ | ✅ |
| Website / URL blocking | ✅ | ❌ |
| In-app section blocking (Reels/Shorts) | ✅ | ❌ |
| Block Settings / Recent apps / Uninstall | ✅ | ❌ |

Koru surfaces an in-app banner when it detects this degraded state, telling
you exactly what is and is not being enforced.

## Privacy posture

Everything Koru does happens on-device: no account, no telemetry, no crash
reporters, no sockets opened by Koru itself. Your blocklists, overlays,
intentions, and stats live in local SQLite/Hive storage and are gone when you
uninstall. See the **Privacy** section of the [README](README.md).

## Reporting a vulnerability

Found a way to bypass enforcement that should be hardened, or a privacy issue?
Please open an issue on the GitHub repository (or contact the maintainer
listed there). Honest bypass reports are welcome — they make the deterrent
better.
