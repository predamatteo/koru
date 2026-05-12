import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/day_flags.dart';

void main() {
  group('DayFlags bit values', () {
    test('per-day bitmask is the power-of-two ladder', () {
      expect(DayFlags.monday, 1);
      expect(DayFlags.tuesday, 2);
      expect(DayFlags.wednesday, 4);
      expect(DayFlags.thursday, 8);
      expect(DayFlags.friday, 16);
      expect(DayFlags.saturday, 32);
      expect(DayFlags.sunday, 64);
    });

    test('grouped masks: allDays / weekdays / weekend', () {
      expect(DayFlags.allDays, 127);
      expect(DayFlags.weekdays, 31);
      expect(DayFlags.weekend, 96);
    });

    test('allDays equals the union of all individual day bits', () {
      final union = DayFlags.monday |
          DayFlags.tuesday |
          DayFlags.wednesday |
          DayFlags.thursday |
          DayFlags.friday |
          DayFlags.saturday |
          DayFlags.sunday;
      expect(union, DayFlags.allDays);
    });

    test('weekdays is Mon..Fri union, weekend is Sat+Sun union', () {
      final weekdays = DayFlags.monday |
          DayFlags.tuesday |
          DayFlags.wednesday |
          DayFlags.thursday |
          DayFlags.friday;
      final weekend = DayFlags.saturday | DayFlags.sunday;
      expect(weekdays, DayFlags.weekdays);
      expect(weekend, DayFlags.weekend);
    });
  });

  group('DayFlags.hasDay', () {
    test('allDays contains every individual day', () {
      expect(DayFlags.hasDay(DayFlags.allDays, DayFlags.monday), isTrue);
      expect(DayFlags.hasDay(DayFlags.allDays, DayFlags.sunday), isTrue);
    });

    test('weekend does NOT contain Monday', () {
      expect(DayFlags.hasDay(DayFlags.weekend, DayFlags.monday), isFalse);
    });

    test('weekend contains Saturday and Sunday', () {
      expect(DayFlags.hasDay(DayFlags.weekend, DayFlags.saturday), isTrue);
      expect(DayFlags.hasDay(DayFlags.weekend, DayFlags.sunday), isTrue);
    });

    test('weekdays does NOT contain Saturday/Sunday', () {
      expect(DayFlags.hasDay(DayFlags.weekdays, DayFlags.saturday), isFalse);
      expect(DayFlags.hasDay(DayFlags.weekdays, DayFlags.sunday), isFalse);
    });

    test('empty flags contains no day', () {
      expect(DayFlags.hasDay(0, DayFlags.monday), isFalse);
      expect(DayFlags.hasDay(0, DayFlags.sunday), isFalse);
    });
  });

  group('DayFlags.toggleDay', () {
    test('toggling a present bit removes it (monday ^ monday == 0)', () {
      expect(DayFlags.toggleDay(DayFlags.monday, DayFlags.monday), 0);
    });

    test('toggling on empty sets the bit (0 ^ friday == friday)', () {
      expect(DayFlags.toggleDay(0, DayFlags.friday), DayFlags.friday);
    });

    test('toggle is its own inverse', () {
      const initial = DayFlags.monday | DayFlags.wednesday;
      final once = DayFlags.toggleDay(initial, DayFlags.friday);
      final twice = DayFlags.toggleDay(once, DayFlags.friday);
      expect(twice, initial);
    });

    test('toggling allDays with monday clears monday only', () {
      final result = DayFlags.toggleDay(DayFlags.allDays, DayFlags.monday);
      expect(DayFlags.hasDay(result, DayFlags.monday), isFalse);
      expect(DayFlags.hasDay(result, DayFlags.tuesday), isTrue);
      expect(DayFlags.hasDay(result, DayFlags.sunday), isTrue);
    });
  });

  group('DayFlags.activeLabels', () {
    test('weekdays → Mon..Fri', () {
      expect(
        DayFlags.activeLabels(DayFlags.weekdays),
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      );
    });

    test('weekend → Sat, Sun', () {
      expect(DayFlags.activeLabels(DayFlags.weekend), ['Sat', 'Sun']);
    });

    test('empty flags → empty list', () {
      expect(DayFlags.activeLabels(0), <String>[]);
    });

    test('monday | wednesday | friday → Mon, Wed, Fri (ordered)', () {
      final flags = DayFlags.monday | DayFlags.wednesday | DayFlags.friday;
      expect(DayFlags.activeLabels(flags), ['Mon', 'Wed', 'Fri']);
    });

    test('allDays → all 7 short labels in week order', () {
      expect(
        DayFlags.activeLabels(DayFlags.allDays),
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
    });

    test('returns a fixed-length (non-growable) list', () {
      final labels = DayFlags.activeLabels(DayFlags.weekend);
      expect(() => labels.add('Foo'), throwsUnsupportedError);
    });
  });

  group('DayFlags.fromDartWeekday', () {
    test('maps every Dart weekday (1..7) to its bit', () {
      expect(DayFlags.fromDartWeekday(DateTime.monday), DayFlags.monday);
      expect(DayFlags.fromDartWeekday(DateTime.tuesday), DayFlags.tuesday);
      expect(DayFlags.fromDartWeekday(DateTime.wednesday), DayFlags.wednesday);
      expect(DayFlags.fromDartWeekday(DateTime.thursday), DayFlags.thursday);
      expect(DayFlags.fromDartWeekday(DateTime.friday), DayFlags.friday);
      expect(DayFlags.fromDartWeekday(DateTime.saturday), DayFlags.saturday);
      expect(DayFlags.fromDartWeekday(DateTime.sunday), DayFlags.sunday);
    });

    test('returns 0 for inputs out of range (below)', () {
      expect(DayFlags.fromDartWeekday(0), 0);
      expect(DayFlags.fromDartWeekday(-1), 0);
    });

    test('returns 0 for inputs out of range (above)', () {
      expect(DayFlags.fromDartWeekday(8), 0);
      expect(DayFlags.fromDartWeekday(100), 0);
    });
  });

  group('DayFlags.ordered & shortLabels', () {
    test('ordered lists every day exactly once in Mon..Sun order', () {
      expect(DayFlags.ordered, <int>[
        DayFlags.monday,
        DayFlags.tuesday,
        DayFlags.wednesday,
        DayFlags.thursday,
        DayFlags.friday,
        DayFlags.saturday,
        DayFlags.sunday,
      ]);
    });

    test('shortLabels covers every ordered day', () {
      for (final bit in DayFlags.ordered) {
        expect(DayFlags.shortLabels[bit], isNotNull);
      }
    });
  });
}
