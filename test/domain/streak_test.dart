import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/streak.dart';

void main() {
  group('StreakId', () {
    test('keys are the lowercase enum names', () {
      expect(StreakId.focus.key, 'focus');
      expect(StreakId.mindful.key, 'mindful');
      expect(StreakId.clean.key, 'clean');
    });

    test('fromKey returns the matching value', () {
      expect(StreakId.fromKey('focus'), StreakId.focus);
      expect(StreakId.fromKey('mindful'), StreakId.mindful);
      expect(StreakId.fromKey('clean'), StreakId.clean);
    });

    test('fromKey returns null for unknown keys', () {
      expect(StreakId.fromKey('bogus'), isNull);
      expect(StreakId.fromKey(''), isNull);
      expect(StreakId.fromKey('FOCUS'), isNull);
    });

    test('keys are unique across all values', () {
      final keys = StreakId.values.map((s) => s.key).toSet();
      expect(keys.length, StreakId.values.length);
    });
  });

  group('StreakSnapshot.empty', () {
    test('produces zeroed snapshot with null lastIncrementedDay', () {
      final snapshot = StreakSnapshot.empty(StreakId.focus);

      expect(snapshot.id, StreakId.focus);
      expect(snapshot.currentCount, 0);
      expect(snapshot.longest, 0);
      expect(snapshot.lastIncrementedDay, isNull);
    });

    test('works for all StreakId values', () {
      for (final id in StreakId.values) {
        final snapshot = StreakSnapshot.empty(id);
        expect(snapshot.id, id);
        expect(snapshot.currentCount, 0);
        expect(snapshot.longest, 0);
        expect(snapshot.lastIncrementedDay, isNull);
      }
    });
  });

  group('dayKeyFor', () {
    test('formats with zero-padded month and day (January 5)', () {
      expect(dayKeyFor(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('handles end-of-year (December 31)', () {
      expect(dayKeyFor(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('zero-pads single-digit month and single-digit day', () {
      expect(dayKeyFor(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('preserves four-digit year padding for small years', () {
      // Defensive — Dart DateTime years are normally 4 digits, but the
      // formatter explicitly pads to 4. Sanity check the padding contract.
      expect(dayKeyFor(DateTime(99, 6, 1)), '0099-06-01');
    });

    test('ignores time-of-day portion', () {
      expect(dayKeyFor(DateTime(2026, 4, 17, 23, 59, 59)), '2026-04-17');
    });
  });

  group('compareDayKeys', () {
    test('returns negative when a < b', () {
      expect(compareDayKeys('2026-01-01', '2026-01-02'), lessThan(0));
    });

    test('returns positive when a > b', () {
      expect(compareDayKeys('2026-01-02', '2026-01-01'), greaterThan(0));
    });

    test('returns zero when keys are equal', () {
      expect(compareDayKeys('2026-01-01', '2026-01-01'), 0);
    });

    test('compares across months and years lexicographically', () {
      expect(compareDayKeys('2025-12-31', '2026-01-01'), lessThan(0));
      expect(compareDayKeys('2026-02-01', '2026-01-31'), greaterThan(0));
    });
  });

  group('isNextDay', () {
    test('detects consecutive days within the same month', () {
      expect(isNextDay('2026-04-17', '2026-04-18'), isTrue);
    });

    test('rejects non-consecutive days (skip one day)', () {
      expect(isNextDay('2026-04-17', '2026-04-19'), isFalse);
    });

    test('rejects equal days (today vs today)', () {
      expect(isNextDay('2026-04-17', '2026-04-17'), isFalse);
    });

    test('rejects reverse order (b before a)', () {
      expect(isNextDay('2026-04-18', '2026-04-17'), isFalse);
    });

    test('handles month rollover (April 30 → May 1)', () {
      expect(isNextDay('2026-04-30', '2026-05-01'), isTrue);
    });

    test('handles year rollover (Dec 31 → Jan 1)', () {
      expect(isNextDay('2026-12-31', '2027-01-01'), isTrue);
    });

    test('handles non-leap February (2025-02-28 → 2025-03-01)', () {
      expect(isNextDay('2025-02-28', '2025-03-01'), isTrue);
    });

    test('handles leap February (2024-02-29 → 2024-03-01)', () {
      expect(isNextDay('2024-02-29', '2024-03-01'), isTrue);
    });

    test('rejects 2025-02-28 → 2025-03-02 (skipped one day)', () {
      expect(isNextDay('2025-02-28', '2025-03-02'), isFalse);
    });
  });
}
