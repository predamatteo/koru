import '../constants/day_flags.dart';

/// Util per verificare se un profilo con time intervals è attivo ora,
/// gestendo correttamente il cross-midnight (porting da
/// minimalist_phone/block_schedule.dart).
class ScheduleUtils {
  const ScheduleUtils._();

  /// Ritorna true se il minuto corrente del giorno cade in [fromMinutes, toMinutes).
  /// Se fromMinutes > toMinutes, si intende cross-midnight
  /// (es. 22:00 - 06:00 = 1320..360).
  static bool isNowInRange({
    required int fromMinutes,
    required int toMinutes,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final nowMinutes = t.hour * 60 + t.minute;
    if (fromMinutes <= toMinutes) {
      return nowMinutes >= fromMinutes && nowMinutes < toMinutes;
    }
    return nowMinutes >= fromMinutes || nowMinutes < toMinutes;
  }

  /// True se il giorno corrente (DateTime.weekday) è nel [dayFlags] bitmask.
  static bool isTodayActive(int dayFlags, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return DayFlags.hasDay(dayFlags, DayFlags.fromDartWeekday(t.weekday));
  }
}
