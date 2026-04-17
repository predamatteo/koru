# Koru

**Koru** (Maori spiral, symbol of inner growth) is a minimalist Android launcher
and mindful blocker that helps you reclaim your attention.

## Features (MVP)

- **Minimalist launcher**: circular clock with battery ring, A-Z drawer with
  haptic fast scroller, reorderable favorites.
- **Blocking profiles** with bit-masked conditions (time window + day flags +
  usage limit) and blocklist/allowlist modes.
- **Per-app overlay designer**: choose background color, message, countdown
  duration, bypass behavior for each app+profile pair.
- **In-app content blocking**: filter Instagram Reels/Stories/Explore and
  YouTube Shorts even when the parent app isn't fully blocked.
- **Browser URL blocking** across 40+ browsers via AccessibilityService.
- **Focus mode**: Quick Block and Pomodoro (work/break cycles) backed by a
  persistent foreground service.
- **Strict mode**: Device Admin lock of Settings / Recent Apps / Uninstall,
  with weekly-rotating backdoor codes for emergency unblock.
- **Mindful intentions**: prompt before opening a blocked app, track
  selections in analytics.
- **Dashboard**: interventions, skipped blocks, focus time, top apps, top
  intentions, daily mood check-in.
- **Onboarding**: permissions flow + 3 ready-made presets (Mindful Morning,
  Deep Work, No Screen Evening) + launcher opt-in.

## Tech stack

- Flutter 3.41 / Dart 3.11
- Riverpod 2.6 (state)
- GoRouter 14.8 (navigation)
- Drift 2.22 (SQLite, 21 tables) + hive_ce 2.10 (KV, 6 boxes)
- fl_chart 0.70 (analytics)
- Kotlin native: AccessibilityService, ForegroundService (specialUse),
  Device Admin, UsageStatsManager, WindowManager overlay (Jetpack Compose).

## Architecture

```
lib/
├── core/         constants, theme, router, utils, DI
├── data/         database (Drift), local (Hive), models, repositories
├── domain/       entities (enum/DTO), usecases
├── platform/    Flutter-side MethodChannel/EventChannel facades
├── presentation/ providers (Riverpod) + screens + widgets
└── l10n/         ARB files + generated

android/app/src/main/kotlin/com/dev/koru/
├── MainActivity.kt
├── channels/    5 MethodChannel + EventChannel bridges
├── service/     KoruAccessibilityService, LockForegroundService,
│                LockRunnable, ForegroundDetector, QuickBlockManager,
│                OverlayManager
├── browser/     URL bar parsing (Chrome/Firefox/Brave/Samsung/Opera/...)
├── content/     InAppContentDetector + Instagram/YouTube detectors
├── strictmode/  StrictModeEnforcer, KoruDeviceAdminReceiver,
│                BackdoorCodeGenerator, StrictModeStore
├── db/          NativeDatabase (read-only SQLite access from
│                :accessibility process)
└── receiver/    BootReceiver
```

## Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```

## Privacy

Everything Koru does happens on-device. No accounts, no ads, no tracking.

## License

Private — all rights reserved.
