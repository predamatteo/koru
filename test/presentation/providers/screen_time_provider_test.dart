import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/statistics_period.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/screen_time_provider.dart';
import 'package:koru/presentation/providers/statistics_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(0);
  });

  group('periodUsageProvider', () {
    test('uses selectedPeriod range to query usage stats', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => [
            AppUsageInfo(
              packageName: 'com.x',
              totalTimeMs: 1000,
              lastTimeUsed: 0,
            ),
          ]);

      final list = await h.container.read(periodUsageProvider.future);
      expect(list, hasLength(1));
      expect(list.single.packageName, 'com.x');
      verify(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).called(1);
    });
  });

  group('periodUsageProvider con navigazione ai giorni passati', () {
    test('interroga il giorno navigato, per intero', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final calls = <({int start, int end})>[];
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((inv) async {
        calls.add((
          start: inv.namedArguments[#startMs] as int,
          end: inv.namedArguments[#endMs] as int,
        ));
        return const [];
      });

      h.container.read(selectedDayOffsetProvider.notifier).state = 2;
      await h.container.read(periodUsageProvider.future);

      final now = DateTime.now();
      final expectedFrom = DateTime(now.year, now.month, now.day - 2);
      final expectedTo = DateTime(now.year, now.month, now.day - 1);
      expect(calls, hasLength(1));
      expect(calls.single.start, expectedFrom.millisecondsSinceEpoch);
      expect(calls.single.end, expectedTo.millisecondsSinceEpoch);
    });

    test('il delta scorre con la finestra: ieri si confronta con l\'altroieri',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final calls = <({int start, int end})>[];
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((inv) async {
        calls.add((
          start: inv.namedArguments[#startMs] as int,
          end: inv.namedArguments[#endMs] as int,
        ));
        return const [];
      });

      h.container.read(selectedDayOffsetProvider.notifier).state = 1;
      await h.container.read(previousPeriodScreenTimeMsProvider.future);

      final now = DateTime.now();
      expect(calls, hasLength(1));
      expect(
        calls.single.end,
        DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch,
      );
      // Finestra di un giorno pieno che finisce dove comincia quello mostrato.
      expect(
        calls.single.end - calls.single.start,
        const Duration(days: 1).inMilliseconds,
      );
    });
  });

  group('periodScreenTimeMsProvider', () {
    test('sums totalTimeMs across all apps in period', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => [
            AppUsageInfo(
                packageName: 'com.a', totalTimeMs: 1000, lastTimeUsed: 0),
            AppUsageInfo(
                packageName: 'com.b', totalTimeMs: 2500, lastTimeUsed: 0),
          ]);

      final total = await h.container.read(periodScreenTimeMsProvider.future);
      expect(total, 3500);
    });

    test('returns 0 when there is no usage', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => const []);

      final total = await h.container.read(periodScreenTimeMsProvider.future);
      expect(total, 0);
    });
  });

  group('previousPeriodScreenTimeMsProvider', () {
    test('queries the window prior to the current period', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // Capture starts/ends.
      final callRanges = <({int start, int end})>[];
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((inv) async {
        callRanges.add((
          start: inv.namedArguments[#startMs] as int,
          end: inv.namedArguments[#endMs] as int,
        ));
        return const [];
      });

      // Set the current period.
      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.today;

      await h.container.read(previousPeriodScreenTimeMsProvider.future);

      // Una sola call (questa provider non dipende dal current).
      expect(callRanges, hasLength(1));
      // L'ordine: prevFrom < prevTo, e prevTo equivale a `from` del periodo.
      expect(callRanges.single.end - callRanges.single.start, greaterThan(0));
    });
  });

  group('topAppsByUsageProvider', () {
    test('returns top N by totalTimeMs (descending)', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => [
            AppUsageInfo(
                packageName: 'com.a', totalTimeMs: 1000, lastTimeUsed: 0),
            AppUsageInfo(
                packageName: 'com.b', totalTimeMs: 5000, lastTimeUsed: 0),
            AppUsageInfo(
                packageName: 'com.c', totalTimeMs: 2000, lastTimeUsed: 0),
            AppUsageInfo(
                packageName: 'com.d', totalTimeMs: 3000, lastTimeUsed: 0),
          ]);

      final top2 = await h.container.read(topAppsByUsageProvider(2).future);
      expect(top2.map((a) => a.packageName), ['com.b', 'com.d']);

      final top10 = await h.container.read(topAppsByUsageProvider(10).future);
      expect(top10, hasLength(4));
      expect(top10.first.packageName, 'com.b');
    });

    test('returns empty list when no usage', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => const []);

      final top = await h.container.read(topAppsByUsageProvider(3).future);
      expect(top, isEmpty);
    });
  });

  group('weeklyTopAppsProvider', () {
    test('sorts by totalTimeMs descending over a ~7-day window', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      ({int start, int end})? captured;
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((inv) async {
        captured = (
          start: inv.namedArguments[#startMs] as int,
          end: inv.namedArguments[#endMs] as int,
        );
        return [
          AppUsageInfo(
              packageName: 'com.a', totalTimeMs: 1000, lastTimeUsed: 0),
          AppUsageInfo(
              packageName: 'com.b', totalTimeMs: 5000, lastTimeUsed: 0),
          AppUsageInfo(
              packageName: 'com.c', totalTimeMs: 2000, lastTimeUsed: 0),
        ];
      });

      final ranking = await h.container.read(weeklyTopAppsProvider.future);
      expect(ranking.map((a) => a.packageName), ['com.b', 'com.c', 'com.a']);

      expect(captured, isNotNull);
      final spanDays = (captured!.end - captured!.start) / (24 * 3600 * 1000);
      expect(spanDays, greaterThan(5.9));
      expect(spanDays, lessThan(7.1));
    });

    test('does not depend on the statistics period selection', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final ranges = <({int start, int end})>[];
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((inv) async {
        ranges.add((
          start: inv.namedArguments[#startMs] as int,
          end: inv.namedArguments[#endMs] as int,
        ));
        return const <AppUsageInfo>[];
      });

      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.today;
      await h.container.read(weeklyTopAppsProvider.future);
      final first = ranges.single;

      // Cambiare periodo NON deve invalidare il ranking settimanale.
      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.week;
      await h.container.read(weeklyTopAppsProvider.future);

      expect(ranges, hasLength(1));
      expect(first.end - first.start, greaterThan(0));
    });
  });

  group('mostUsedAppSuggestions', () {
    List<AppUsageInfo> ranking(List<(String, int)> entries) => [
          for (final (pkg, ms) in entries)
            AppUsageInfo(packageName: pkg, totalTimeMs: ms, lastTimeUsed: 0),
        ];

    test('returns the top 3 by weekly usage', () {
      final out = mostUsedAppSuggestions(
        weeklyRanking: ranking([
          ('com.a', 5000),
          ('com.b', 4000),
          ('com.c', 3000),
          ('com.d', 2000),
        ]),
        installedPackages: {'com.a', 'com.b', 'com.c', 'com.d'},
        alreadySelected: const {},
      );
      expect(out, ['com.a', 'com.b', 'com.c']);
    });

    test('skips apps already selected and promotes the next ones', () {
      final out = mostUsedAppSuggestions(
        weeklyRanking: ranking([
          ('com.a', 5000),
          ('com.b', 4000),
          ('com.c', 3000),
          ('com.d', 2000),
          ('com.e', 1000),
        ]),
        installedPackages: {'com.a', 'com.b', 'com.c', 'com.d', 'com.e'},
        alreadySelected: const {'com.a', 'com.c'},
      );
      expect(out, ['com.b', 'com.d', 'com.e']);
    });

    test('skips packages that are no longer installed', () {
      final out = mostUsedAppSuggestions(
        weeklyRanking: ranking([
          ('com.gone', 9000),
          ('com.a', 5000),
          ('com.b', 4000),
        ]),
        installedPackages: {'com.a', 'com.b'},
        alreadySelected: const {},
      );
      expect(out, ['com.a', 'com.b']);
    });

    test('never suggests Koru itself nor zero-time entries', () {
      final out = mostUsedAppSuggestions(
        weeklyRanking: ranking([
          ('com.dev.koru', 99000),
          ('com.zero', 0),
          ('com.a', 1000),
        ]),
        installedPackages: {'com.dev.koru', 'com.zero', 'com.a'},
        alreadySelected: const {},
      );
      expect(out, ['com.a']);
    });

    test('returns fewer than 3 when there are not enough candidates', () {
      expect(
        mostUsedAppSuggestions(
          weeklyRanking: ranking([('com.a', 1000)]),
          installedPackages: {'com.a'},
          alreadySelected: const {'com.a'},
        ),
        isEmpty,
      );
    });
  });

  group('weeklyDailyUsageProvider', () {
    test('returns 7 ascending days, zero-filled, mapping native data',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final now = DateTime.now();
      final todayKey =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

      when(() => h.blocking.getUsageStatsByDay(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => [
            DailyUsage(
              dayStartMs: todayKey,
              apps: [
                AppUsageInfo(
                    packageName: 'com.a', totalTimeMs: 3000, lastTimeUsed: 0),
              ],
            ),
          ]);

      final week = await h.container.read(weeklyDailyUsageProvider.future);
      expect(week, hasLength(7));
      for (var i = 1; i < week.length; i++) {
        expect(week[i].dayStartMs, greaterThan(week[i - 1].dayStartMs));
      }
      // The last bucket is today and carries the native data.
      expect(week.last.dayStartMs, todayKey);
      expect(week.last.apps, hasLength(1));
      expect(week.last.totalMs, 3000);
      // Earlier days are zero-filled.
      expect(week.first.apps, isEmpty);
      expect(week.first.totalMs, 0);
    });

    test('queries roughly a 7-day window', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      ({int start, int end})? captured;
      when(() => h.blocking.getUsageStatsByDay(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((inv) async {
        captured = (
          start: inv.namedArguments[#startMs] as int,
          end: inv.namedArguments[#endMs] as int,
        );
        return const <DailyUsage>[];
      });

      await h.container.read(weeklyDailyUsageProvider.future);
      expect(captured, isNotNull);
      final spanDays =
          (captured!.end - captured!.start) / (24 * 3600 * 1000);
      // 6 full days back + part of today → between ~6 and ~7 days.
      expect(spanDays, greaterThan(5.9));
      expect(spanDays, lessThan(7.1));
    });
  });

  group('selectedDayUsageProvider', () {
    test('is null when no day is selected', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStatsByDay(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => const <DailyUsage>[]);

      await h.container.read(weeklyDailyUsageProvider.future);
      expect(h.container.read(selectedDayUsageProvider), isNull);
    });

    test('returns the matching day when one is selected', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final now = DateTime.now();
      final todayKey =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      when(() => h.blocking.getUsageStatsByDay(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => [
            DailyUsage(
              dayStartMs: todayKey,
              apps: [
                AppUsageInfo(
                    packageName: 'com.a', totalTimeMs: 1000, lastTimeUsed: 0),
              ],
            ),
          ]);

      await h.container.read(weeklyDailyUsageProvider.future);
      h.container.read(selectedStatsDayProvider.notifier).state = todayKey;

      final sel = h.container.read(selectedDayUsageProvider);
      expect(sel, isNotNull);
      expect(sel!.dayStartMs, todayKey);
      expect(sel.totalMs, 1000);
    });

    test('is null when the selected day is not in the week data', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getUsageStatsByDay(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async => const <DailyUsage>[]);

      await h.container.read(weeklyDailyUsageProvider.future);
      h.container.read(selectedStatsDayProvider.notifier).state = 99;
      expect(h.container.read(selectedDayUsageProvider), isNull);
    });
  });
}
