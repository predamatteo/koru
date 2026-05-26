import '../constants/day_flags.dart';

/// Util per verificare se un profilo con time intervals è attivo ora,
/// gestendo correttamente il cross-midnight (porting da
/// minimalist_phone/block_schedule.dart).
class ScheduleUtils {
  const ScheduleUtils._();

  /// Ritorna true se il minuto corrente del giorno cade nell'intervallo.
  ///
  /// Semantica CANONICA, allineata 1:1 a
  /// `BlockPolicyEvaluator.isNowInInterval` (Kotlin, l'unica fonte di verità
  /// dell'enforcement nativo). Ogni divergenza qui è un buco: la UI "attivo
  /// ora" mostrerebbe uno stato diverso da quello che il motore applica.
  ///   - `from == to` ⇒ 24h (sempre dentro). NB: prima questo caso tornava
  ///     "mai" (il vecchio `>= from && < to` con from==to è sempre false),
  ///     divergendo sia dal nativo sia dal modello "intervallo a giornata
  ///     intera". Ora un profilo con from==to risulta attivo tutto il giorno.
  ///   - `from <  to` ⇒ half-open `[from, to)` (to escluso).
  ///   - `from >  to` ⇒ cross-midnight (es. 22:00→06:00 = 1320→360): dentro se
  ///     `now >= from || now < to`.
  static bool isNowInRange({
    required int fromMinutes,
    required int toMinutes,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final nowMinutes = t.hour * 60 + t.minute;
    if (fromMinutes == toMinutes) return true; // 24h
    if (fromMinutes < toMinutes) {
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
