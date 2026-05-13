import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/domain/entities/statistics_period.dart';
import 'package:koru/presentation/providers/statistics_providers.dart';

import '../../_helpers/provider_test_utils.dart';

/// Helper: today's day-key matching StatisticsPeriod.currentRange formatting.
String _todayKey() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  group('selectedPeriodProvider', () {
    test('defaults to today', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      expect(
        h.container.read(selectedPeriodProvider),
        StatisticsPeriod.today,
      );
    });

    test('can be set to week', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.week;
      expect(
        h.container.read(selectedPeriodProvider),
        StatisticsPeriod.week,
      );
    });
  });

  group('blockTriggeredCountProvider', () {
    test('emits 0 on empty db', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final v =
          await h.container.read(blockTriggeredCountProvider.stream).first;
      expect(v, 0);
    });

    test('counts events with eventType=0 in the selected period', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );
      // Skipped (different eventType) — non deve essere contato.
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 1,
          restrictionType: 0,
        ),
      );

      final v =
          await h.container.read(blockTriggeredCountProvider.stream).first;
      expect(v, 2);
    });
  });

  group('blockSkippedCountProvider', () {
    test('counts events with eventType=1', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 1,
          restrictionType: 0,
        ),
      );

      final v = await h.container.read(blockSkippedCountProvider.stream).first;
      expect(v, 1);
    });
  });

  group('perAppBreakdownProvider', () {
    test('returns per-app+per-eventType aggregated counts', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 3; i++) {
        await h.db.restrictedAccessEventsDao.insertEvent(
          RestrictedAccessEventsCompanion.insert(
            occurredAt: now,
            dayStartDate: today,
            packageName: 'com.a',
            eventType: 0,
            restrictionType: 0,
          ),
        );
      }
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.b',
          eventType: 0,
          restrictionType: 0,
        ),
      );

      final rows =
          await h.container.read(perAppBreakdownProvider.stream).first;
      expect(rows, hasLength(2));
      // Ordinato desc per cnt → com.a (3) prima.
      expect(rows.first.packageName, 'com.a');
      expect(rows.first.count, 3);
      expect(rows.last.packageName, 'com.b');
      expect(rows.last.count, 1);
    });
  });

  group('topIntentionsProvider', () {
    test('returns intention titles sorted by usage count desc', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      // 3x "check_messages", 1x "post"
      for (var i = 0; i < 3; i++) {
        await h.db.intentionUsageEventsDao.insertEvent(
          IntentionUsageEventsCompanion.insert(
            occurredAt: now,
            dayStartDate: today,
            packageName: 'com.x',
            intentionName: 'check_messages',
          ),
        );
      }
      await h.db.intentionUsageEventsDao.insertEvent(
        IntentionUsageEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          intentionName: 'post',
        ),
      );

      final rows = await h.container.read(topIntentionsProvider.stream).first;
      expect(rows, hasLength(2));
      expect(rows.first.title, 'check_messages');
      expect(rows.first.usageCount, 3);
      expect(rows.last.title, 'post');
      expect(rows.last.usageCount, 1);
    });
  });

  group('focusTimeMsProvider', () {
    test('sums focus durations within the period', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.focusUsageEventsDao.insertEvent(
        FocusUsageEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          durationInMs: 60000,
        ),
      );
      await h.db.focusUsageEventsDao.insertEvent(
        FocusUsageEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          durationInMs: 30000,
        ),
      );

      final v = await h.container.read(focusTimeMsProvider.stream).first;
      expect(v, 90000);
    });

    test('returns 0 when there are no events', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final v = await h.container.read(focusTimeMsProvider.stream).first;
      expect(v, 0);
    });
  });
}
