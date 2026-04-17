import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/day_flags.dart';
import 'package:koru/core/utils/schedule_utils.dart';

void main() {
  group('ScheduleUtils.isNowInRange', () {
    test('same-day range inclusive start, exclusive end', () {
      final noon = DateTime(2026, 4, 17, 12, 0);
      expect(
        ScheduleUtils.isNowInRange(fromMinutes: 9 * 60, toMinutes: 17 * 60, now: noon),
        isTrue,
      );
      final pre = DateTime(2026, 4, 17, 8, 59);
      expect(
        ScheduleUtils.isNowInRange(fromMinutes: 9 * 60, toMinutes: 17 * 60, now: pre),
        isFalse,
      );
      final exactEnd = DateTime(2026, 4, 17, 17, 0);
      expect(
        ScheduleUtils.isNowInRange(fromMinutes: 9 * 60, toMinutes: 17 * 60, now: exactEnd),
        isFalse,
      );
    });

    test('cross-midnight range covers both sides', () {
      final late = DateTime(2026, 4, 17, 23, 30);
      final early = DateTime(2026, 4, 17, 3, 0);
      final noon = DateTime(2026, 4, 17, 12, 0);
      expect(
        ScheduleUtils.isNowInRange(fromMinutes: 22 * 60, toMinutes: 6 * 60, now: late),
        isTrue,
      );
      expect(
        ScheduleUtils.isNowInRange(fromMinutes: 22 * 60, toMinutes: 6 * 60, now: early),
        isTrue,
      );
      expect(
        ScheduleUtils.isNowInRange(fromMinutes: 22 * 60, toMinutes: 6 * 60, now: noon),
        isFalse,
      );
    });
  });

  group('ScheduleUtils.isTodayActive', () {
    test('matches dayFlags for current Dart weekday', () {
      final mon = DateTime(2026, 4, 13); // Monday
      expect(ScheduleUtils.isTodayActive(DayFlags.weekdays, now: mon), isTrue);
      expect(ScheduleUtils.isTodayActive(DayFlags.weekend, now: mon), isFalse);

      final sat = DateTime(2026, 4, 18); // Saturday
      expect(ScheduleUtils.isTodayActive(DayFlags.weekend, now: sat), isTrue);
      expect(ScheduleUtils.isTodayActive(DayFlags.weekdays, now: sat), isFalse);
    });
  });
}
