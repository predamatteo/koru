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
}
