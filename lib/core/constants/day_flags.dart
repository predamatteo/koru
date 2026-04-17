/// Bitmask per i giorni della settimana.
/// bit 0 = Monday, bit 1 = Tuesday, ... bit 6 = Sunday.
/// 127 = ogni giorno.
abstract class DayFlags {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 4;
  static const int thursday = 8;
  static const int friday = 16;
  static const int saturday = 32;
  static const int sunday = 64;

  static const int allDays = 127; // 0111_1111
  static const int weekdays = 31; // Mon-Fri
  static const int weekend = 96; // Sat+Sun

  static const List<int> ordered = [
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
  ];

  static const Map<int, String> shortLabels = {
    monday: 'Mon',
    tuesday: 'Tue',
    wednesday: 'Wed',
    thursday: 'Thu',
    friday: 'Fri',
    saturday: 'Sat',
    sunday: 'Sun',
  };

  static bool hasDay(int flags, int day) => flags & day != 0;
  static int toggleDay(int flags, int day) => flags ^ day;

  static List<String> activeLabels(int flags) =>
      ordered.where((d) => hasDay(flags, d)).map((d) => shortLabels[d]!).toList(growable: false);

  /// Dart weekday (1=Mon..7=Sun) → DayFlags bit.
  static int fromDartWeekday(int dartWeekday) {
    switch (dartWeekday) {
      case DateTime.monday:
        return monday;
      case DateTime.tuesday:
        return tuesday;
      case DateTime.wednesday:
        return wednesday;
      case DateTime.thursday:
        return thursday;
      case DateTime.friday:
        return friday;
      case DateTime.saturday:
        return saturday;
      case DateTime.sunday:
        return sunday;
      default:
        return 0;
    }
  }
}
