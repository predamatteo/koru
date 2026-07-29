import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/koru_colors.dart';
import 'package:koru/core/theme/launcher_phase.dart';

void main() {
  group('LauncherPhase.forHour', () {
    test('07:00 is the first hour of the day band, 19:xx the last', () {
      expect(LauncherPhase.forHour(7), LauncherPhase.day);
      expect(LauncherPhase.forHour(13), LauncherPhase.day);
      expect(LauncherPhase.forHour(19), LauncherPhase.day);
    });

    test('20:00 through 06:xx is night', () {
      expect(LauncherPhase.forHour(20), LauncherPhase.night);
      expect(LauncherPhase.forHour(23), LauncherPhase.night);
      expect(LauncherPhase.forHour(0), LauncherPhase.night);
      expect(LauncherPhase.forHour(6), LauncherPhase.night);
    });
  });

  group('LauncherPhase.nextBoundary', () {
    test('before 07:00 the next boundary is 07:00 the same day', () {
      final b = LauncherPhase.nextBoundary(DateTime(2026, 7, 29, 3, 12));
      expect(b, DateTime(2026, 7, 29, 7));
    });

    test('during the day the next boundary is 20:00 the same day', () {
      final b = LauncherPhase.nextBoundary(DateTime(2026, 7, 29, 13, 7));
      expect(b, DateTime(2026, 7, 29, 20));
    });

    test('in the evening the next boundary is 07:00 the day after', () {
      final b = LauncherPhase.nextBoundary(DateTime(2026, 7, 29, 22, 18));
      expect(b, DateTime(2026, 7, 30, 7));
    });

    test('crossing a month end lands on the first of the next month', () {
      final b = LauncherPhase.nextBoundary(DateTime(2026, 7, 31, 23, 59));
      expect(b, DateTime(2026, 8, 1, 7));
    });

    test('the boundary is always strictly in the future', () {
      for (var hour = 0; hour < 24; hour++) {
        final now = DateTime(2026, 7, 29, hour, 30);
        expect(
          LauncherPhase.nextBoundary(now).isAfter(now),
          isTrue,
          reason: 'boundary must be ahead of $hour:30',
        );
      }
    });

    test('crossing the boundary actually flips the phase', () {
      for (final now in [
        DateTime(2026, 7, 29, 3),
        DateTime(2026, 7, 29, 13),
        DateTime(2026, 7, 29, 22),
      ]) {
        final boundary = LauncherPhase.nextBoundary(now);
        expect(
          LauncherPhase.at(boundary),
          isNot(LauncherPhase.at(now)),
          reason: 'the phase at $boundary must differ from the one at $now',
        );
      }
    });
  });

  group('palette', () {
    test('surfaces and outline come from the existing Koru tonal scale', () {
      expect(LauncherPhase.day.background, KoruColors.surface);
      expect(LauncherPhase.night.background, KoruColors.backgroundBase);
      expect(LauncherPhase.day.hair, KoruColors.outline);
      expect(LauncherPhase.night.hair, KoruColors.surfaceElevated);
    });

    test('one accent per band, both already in the Koru palette', () {
      expect(LauncherPhase.day.accent, KoruColors.primary);
      expect(LauncherPhase.night.accent, KoruColors.tertiary);
    });

    test('night lowers the light: dimmer text, wider breathing, faded clock',
        () {
      expect(LauncherPhase.night.ink, isNot(LauncherPhase.day.ink));
      expect(LauncherPhase.night.gap, greaterThan(LauncherPhase.day.gap));
      expect(
        LauncherPhase.night.trackEm,
        greaterThan(LauncherPhase.day.trackEm),
      );
      expect(
        LauncherPhase.night.clockOpacity,
        lessThan(LauncherPhase.day.clockOpacity),
      );
    });
  });
}
