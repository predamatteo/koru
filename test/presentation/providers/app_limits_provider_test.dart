import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_limits_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String, AppLimitConfig>{});
  });

  /// Stub di base per le interazioni di `setLimit` (trigger achievement,
  /// strict-mode, blocking config). Tutte ritornano OK così la pipe non
  /// fallisce.
  void primeForMutations(TestHarness h) {
    // achievementEvaluationProvider.trigger ha bisogno di parecchi stub —
    // dato che lavora con DAO reali (db in-memory è ok) e channel mockati,
    // copro le call che farà.
    when(() => h.blocking.getAppDailyLimits())
        .thenAnswer((_) async => const <String, AppLimitConfig>{});
    when(() => h.blocking.setAppDailyLimits(any()))
        .thenAnswer((_) async => true);
    when(() => h.strict.getStrictModeOptions()).thenAnswer((_) async => 0);
  }

  group('appLimitsProvider', () {
    test('build() fetches current limits from blocking channel', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.x': const AppLimitConfig(minutes: 30, strict: true),
        },
      );

      final map = await h.container.read(appLimitsProvider.future);
      expect(map, hasLength(1));
      expect(map['com.x']!.minutes, 30);
      expect(map['com.x']!.strict, isTrue);
    });

    test('build() returns empty map when nothing is set', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits())
          .thenAnswer((_) async => const <String, AppLimitConfig>{});

      final map = await h.container.read(appLimitsProvider.future);
      expect(map, isEmpty);
    });

    test('setLimit() adds a new package with default strict=true', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      primeForMutations(h);
      await h.container.read(appLimitsProvider.future);

      await h.container
          .read(appLimitsProvider.notifier)
          .setLimit('com.x', 30);

      final next = h.container.read(appLimitsProvider).valueOrNull!;
      expect(next['com.x']!.minutes, 30);
      expect(next['com.x']!.strict, isTrue);
      verify(() => h.blocking.setAppDailyLimits(any())).called(1);
    });

    test('setLimit() with minutes<=0 removes the entry', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.x': const AppLimitConfig(minutes: 30, strict: true),
        },
      );
      when(() => h.blocking.setAppDailyLimits(any()))
          .thenAnswer((_) async => true);
      when(() => h.strict.getStrictModeOptions()).thenAnswer((_) async => 0);

      await h.container.read(appLimitsProvider.future);

      await h.container
          .read(appLimitsProvider.notifier)
          .setLimit('com.x', 0);

      final next = h.container.read(appLimitsProvider).valueOrNull!;
      expect(next, isEmpty);
    });

    test('setLimit() preserves existing strict flag if not passed',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.x': const AppLimitConfig(minutes: 30, strict: false),
        },
      );
      when(() => h.blocking.setAppDailyLimits(any()))
          .thenAnswer((_) async => true);
      when(() => h.strict.getStrictModeOptions()).thenAnswer((_) async => 0);

      await h.container.read(appLimitsProvider.future);

      await h.container
          .read(appLimitsProvider.notifier)
          .setLimit('com.x', 60);

      final next = h.container.read(appLimitsProvider).valueOrNull!;
      expect(next['com.x']!.minutes, 60);
      expect(next['com.x']!.strict, isFalse);
    });

    test('setStrict() is a no-op when the package has no current limit',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits())
          .thenAnswer((_) async => const <String, AppLimitConfig>{});

      await h.container.read(appLimitsProvider.future);

      await h.container
          .read(appLimitsProvider.notifier)
          .setStrict('com.unknown', true);

      verifyNever(() => h.blocking.setAppDailyLimits(any()));
    });

    test('setStrict() updates only the strict flag (no minutes change)',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.x': const AppLimitConfig(minutes: 30, strict: false),
        },
      );
      when(() => h.blocking.setAppDailyLimits(any()))
          .thenAnswer((_) async => true);
      when(() => h.blocking.resetBypassCount(any())).thenAnswer((_) async {});

      await h.container.read(appLimitsProvider.future);

      await h.container
          .read(appLimitsProvider.notifier)
          .setStrict('com.x', true);

      final next = h.container.read(appLimitsProvider).valueOrNull!;
      expect(next['com.x']!.strict, isTrue);
      expect(next['com.x']!.minutes, 30);
      // setStrict(true) deve resettare il bypass count.
      verify(() => h.blocking.resetBypassCount('com.x')).called(1);
    });

    test('setStrict() no-op when flag matches current value', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.x': const AppLimitConfig(minutes: 30, strict: true),
        },
      );

      await h.container.read(appLimitsProvider.future);
      await h.container
          .read(appLimitsProvider.notifier)
          .setStrict('com.x', true);

      verifyNever(() => h.blocking.setAppDailyLimits(any()));
    });

    test('clear() removes the limit entry', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.x': const AppLimitConfig(minutes: 30, strict: true),
        },
      );
      when(() => h.blocking.setAppDailyLimits(any()))
          .thenAnswer((_) async => true);
      when(() => h.strict.getStrictModeOptions()).thenAnswer((_) async => 0);

      await h.container.read(appLimitsProvider.future);
      await h.container.read(appLimitsProvider.notifier).clear('com.x');

      final next = h.container.read(appLimitsProvider).valueOrNull!;
      expect(next, isEmpty);
    });
  });

  group('usageTodayMinutesProvider', () {
    test('rounds ms-to-minutes (not floor)', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // 30 seconds → 30000 ms → 0.5 min → rounded to 1 (HALF_UP).
      when(() => h.blocking.getUsageTodayMs('com.x'))
          .thenAnswer((_) async => 30000);

      final minutes =
          await h.container.read(usageTodayMinutesProvider('com.x').future);
      expect(minutes, 1);
    });

    test('returns 0 minutes for 0 ms', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageTodayMs('com.x'))
          .thenAnswer((_) async => 0);

      final minutes =
          await h.container.read(usageTodayMinutesProvider('com.x').future);
      expect(minutes, 0);
    });

    test('integer minute does not lose information', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // Esattamente 2 minuti.
      when(() => h.blocking.getUsageTodayMs('com.y'))
          .thenAnswer((_) async => 120000);

      final minutes =
          await h.container.read(usageTodayMinutesProvider('com.y').future);
      expect(minutes, 2);
    });
  });

  group('bypassCountTodayProvider', () {
    test('forwards getBypassCountToday from blocking', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getBypassCountToday('com.x'))
          .thenAnswer((_) async => 5);

      final count =
          await h.container.read(bypassCountTodayProvider('com.x').future);
      expect(count, 5);
    });
  });
}
