/// Identificatori stabili delle streak tracciate.
/// - [focus]: giorni consecutivi con ≥1 sessione focus completata (≥15 min).
/// - [mindful]: giorni consecutivi con mood check-in registrato.
/// - [clean]: giorni consecutivi senza superare nessun daily limit
///   configurato. Richiede almeno un limite attivo per essere valutata.
enum StreakId {
  focus('focus'),
  mindful('mindful'),
  clean('clean');

  const StreakId(this.key);

  final String key;

  static StreakId? fromKey(String key) =>
      StreakId.values.where((e) => e.key == key).firstOrNull;
}

/// Snapshot immutabile dello stato di una streak.
class StreakSnapshot {
  const StreakSnapshot({
    required this.id,
    required this.currentCount,
    required this.longest,
    this.lastIncrementedDay,
  });

  final StreakId id;
  final int currentCount;
  final int longest;

  /// Day-key locale YYYY-MM-DD dell'ultimo incremento (null se mai incrementata).
  final String? lastIncrementedDay;

  static StreakSnapshot empty(StreakId id) => StreakSnapshot(
        id: id,
        currentCount: 0,
        longest: 0,
      );
}

String dayKeyFor(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Confronta due day-key YYYY-MM-DD. Ritorna:
///   -1 se [a] < [b], 0 se uguali, 1 se [a] > [b].
int compareDayKeys(String a, String b) => a.compareTo(b);

/// Vero se [b] è esattamente il giorno successivo a [a] (stessa calendar
/// logic locale). Assume formato valido.
bool isNextDay(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  final next = DateTime(pa.year, pa.month, pa.day + 1);
  return next.year == pb.year && next.month == pb.month && next.day == pb.day;
}

DateTime _parse(String dayKey) {
  final parts = dayKey.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
