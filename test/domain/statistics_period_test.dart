import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/statistics_period.dart';
import 'package:koru/presentation/l10n/model_labels.dart';

import '../_helpers/l10n_test_utils.dart';

final _en = enL10n;

void main() {
  group('StatisticsPeriod metadata', () {
    test('daysBack is 1 / 7', () {
      expect(StatisticsPeriod.today.daysBack, 1);
      expect(StatisticsPeriod.week.daysBack, 7);
    });

    test('label exposes the user-facing string', () {
      expect(StatisticsPeriod.today.label(_en), 'Today');
      expect(StatisticsPeriod.week.label(_en), 'This week');
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

  /// La navigazione ai giorni passati passa tutta da `shiftDays`: se questa
  /// finestra scivola, ogni card delle Statistiche mente insieme.
  group('StatisticsPeriod con shiftDays', () {
    test('today: shiftDays=1 è ieri, from e to sullo stesso giorno', () {
      final range = StatisticsPeriod.today.currentRange(
        now: DateTime(2026, 4, 17, 14, 30),
        shiftDays: 1,
      );
      expect(range.from, '2026-04-16');
      expect(range.to, '2026-04-16');
    });

    test('today: shiftDays scavalca il confine di mese', () {
      final range = StatisticsPeriod.today.currentRange(
        now: DateTime(2026, 5, 2),
        shiftDays: 4,
      );
      expect(range.from, '2026-04-28');
      expect(range.to, '2026-04-28');
    });

    test('week: shiftDays=7 è la settimana prima, 7 giorni inclusivi', () {
      final range = StatisticsPeriod.week.currentRange(
        now: DateTime(2026, 4, 17),
        shiftDays: 7,
      );
      expect(range.from, '2026-04-04');
      expect(range.to, '2026-04-10');
    });

    test('un giorno passato è contato per intero, non fino a quest ora', () {
      // È la ragione per cui `to` non può restare "adesso": ieri è chiuso, e
      // fermarsi alle 14:30 di ieri taglierebbe via mezza giornata.
      final now = DateTime(2026, 4, 17, 14, 30);
      final range = StatisticsPeriod.today.currentRangeMs(
        now: now,
        shiftDays: 1,
      );
      expect(range.from, DateTime(2026, 4, 16).millisecondsSinceEpoch);
      expect(range.to, DateTime(2026, 4, 17).millisecondsSinceEpoch);
      expect(range.to - range.from, const Duration(days: 1).inMilliseconds);
    });

    test('shiftDays=0 lascia il comportamento di prima (to = adesso)', () {
      final now = DateTime(2026, 4, 17, 14, 30);
      for (final period in StatisticsPeriod.values) {
        expect(
          period.currentRangeMs(now: now, shiftDays: 0),
          period.currentRangeMs(now: now),
          reason: period.name,
        );
        expect(
          period.currentRange(now: now, shiftDays: 0),
          period.currentRange(now: now),
          reason: period.name,
        );
      }
    });

    test('maxDaysBack resta dentro la ritenzione di UsageStatsManager', () {
      // ~7-10 giorni di eventi: oltre, lo screen-time tornerebbe zero senza
      // modo di distinguerlo da "quel giorno non hai usato niente".
      expect(StatisticsPeriod.maxDaysBack, 6);
    });
  });
}
