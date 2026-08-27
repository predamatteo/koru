import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/day_flags.dart';
import 'package:koru/presentation/l10n/model_labels.dart';

import '../../_helpers/l10n_test_utils.dart';

final _en = enL10n;

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

  group('AppLocalizations.activeDayLabels', () {
    test('weekdays → Mon..Fri', () {
      expect(
        _en.activeDayLabels(DayFlags.weekdays),
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      );
    });

    test('weekend → Sat, Sun', () {
      expect(_en.activeDayLabels(DayFlags.weekend), ['Sat', 'Sun']);
    });

    test('empty flags → empty list', () {
      expect(_en.activeDayLabels(0), <String>[]);
    });

    test('monday | wednesday | friday → Mon, Wed, Fri (ordered)', () {
      final flags = DayFlags.monday | DayFlags.wednesday | DayFlags.friday;
      expect(_en.activeDayLabels(flags), ['Mon', 'Wed', 'Fri']);
    });

    test('allDays → all 7 short labels in week order', () {
      expect(
        _en.activeDayLabels(DayFlags.allDays),
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
    });

    test('returns a fixed-length (non-growable) list', () {
      final labels = _en.activeDayLabels(DayFlags.weekend);
      expect(() => labels.add('Foo'), throwsUnsupportedError);
    });

    // Le abbreviazioni sono tradotte: se qualcuno reintroducesse una tabella
    // inglese hardcoded, questo test la vedrebbe.
    test('italian short labels differ from english', () {
      expect(
        itL10n.activeDayLabels(DayFlags.weekdays),
        ['Lun', 'Mar', 'Mer', 'Gio', 'Ven'],
      );
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

  group('DayFlags.ordered & short labels', () {
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

    test('every ordered day has a short label in both locales', () {
      for (final bit in DayFlags.ordered) {
        expect(_en.dayShortLabel(bit), isNotEmpty);
        expect(itL10n.dayShortLabel(bit), isNotEmpty);
      }
    });
  });
}
