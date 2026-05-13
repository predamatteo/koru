import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/statistics_period.dart';

void main() {
  group('StatisticsPeriod metadata', () {
    test('daysBack is 1 / 7', () {
      expect(StatisticsPeriod.today.daysBack, 1);
      expect(StatisticsPeriod.week.daysBack, 7);
    });

    test('label exposes the user-facing string', () {
      expect(StatisticsPeriod.today.label, 'Today');
      expect(StatisticsPeriod.week.label, 'This week');
    });

    test('there are exactly 2 periods', () {
      expect(StatisticsPeriod.values.length, 2);
    });
  });

  group('StatisticsPeriod.currentRange (string YYYY-MM-DD)', () {
    test('today returns same day for from/to', () {
      final range = StatisticsPeriod.today.currentRange(
        now: DateTime(2026, 4, 17),
      );
      expect(range.from, '2026-04-17');
      expect(range.to, '2026-04-17');
    });

    test('week spans 7 days inclusive (April 11..17)', () {
      final range = StatisticsPeriod.week.currentRange(
        now: DateTime(2026, 4, 17),
      );
      expect(range.from, '2026-04-11');
      expect(range.to, '2026-04-17');
    });

    test('single-digit months are zero-padded (January)', () {
      final range = StatisticsPeriod.today.currentRange(
        now: DateTime(2026, 1, 5),
      );
      expect(range.from, '2026-01-05');
      expect(range.to, '2026-01-05');
    });

    test('single-digit day is zero-padded', () {
      final range = StatisticsPeriod.today.currentRange(
        now: DateTime(2026, 7, 9),
      );
      expect(range.from, '2026-07-09');
    });
  });

  group('StatisticsPeriod.currentRangeMs', () {
    test('today: from = startOfDay, to = now timestamp', () {
      final now = DateTime(2026, 4, 17, 14, 30);
      final range = StatisticsPeriod.today.currentRangeMs(now: now);
      final startOfDay = DateTime(2026, 4, 17);

      expect(range.from, startOfDay.millisecondsSinceEpoch);
      expect(range.to, now.millisecondsSinceEpoch);
    });

    test('week: from is startOfDay shifted back by 6 days', () {
      final now = DateTime(2026, 4, 17, 14, 30);
      final range = StatisticsPeriod.week.currentRangeMs(now: now);
      final startOfDay = DateTime(2026, 4, 17);
      final expectedFrom = startOfDay.subtract(const Duration(days: 6));

      expect(range.from, expectedFrom.millisecondsSinceEpoch);
      expect(range.to, now.millisecondsSinceEpoch);
    });

    test('from is always <= to', () {
      final now = DateTime(2026, 4, 17, 14, 30);
      for (final period in StatisticsPeriod.values) {
        final range = period.currentRangeMs(now: now);
        expect(range.from, lessThanOrEqualTo(range.to));
      }
    });

    test('to preserves time-of-day, from snaps to midnight', () {
      final now = DateTime(2026, 4, 17, 23, 59, 59, 999);
      final range = StatisticsPeriod.today.currentRangeMs(now: now);
      final startOfDay = DateTime(2026, 4, 17);

      expect(range.from, startOfDay.millisecondsSinceEpoch);
      expect(range.to, now.millisecondsSinceEpoch);
      expect(range.to - range.from, greaterThan(0));
    });
  });
}
