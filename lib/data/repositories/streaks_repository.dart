import 'package:drift/drift.dart';

import '../../domain/entities/streak.dart';
import '../database/app_database.dart';
import '../database/daos/streaks_dao.dart';

/// Gestisce la logica idempotente di increment/reset delle streak.
class StreaksRepository {
  StreaksRepository(this._dao);

  final StreaksDao _dao;

  /// Segna la streak [id] come "soddisfatta oggi". Idempotente per giorno:
  /// se il giorno corrente è già stato contato, non fa nulla. Altrimenti:
  ///   - se l'ultimo incremento è ieri → incrementa current;
  ///   - se è precedente (gap ≥2) o mai → reset a 1.
  /// Aggiorna [longest] se current supera il record precedente.
  Future<StreakSnapshot> markToday(StreakId id) async {
    final today = dayKeyFor(DateTime.now());
    final row = await _dao.getState(id.key);

    final current = row == null ? 0 : row.currentCount;
    final longest = row == null ? 0 : row.longest;
    final last = row?.lastIncrementedDay;

    int nextCurrent;
    if (last == today) {
      return StreakSnapshot(
        id: id,
        currentCount: current,
        longest: longest,
        lastIncrementedDay: last,
      );
    } else if (last != null && isNextDay(last, today)) {
      nextCurrent = current + 1;
    } else {
      nextCurrent = 1;
    }
    final nextLongest = nextCurrent > longest ? nextCurrent : longest;

    await _dao.upsert(
      StreakStateCompanion(
        id: Value(id.key),
        currentCount: Value(nextCurrent),
        longest: Value(nextLongest),
        lastIncrementedDay: Value(today),
      ),
    );
    return StreakSnapshot(
      id: id,
      currentCount: nextCurrent,
      longest: nextLongest,
      lastIncrementedDay: today,
    );
  }

  /// Snapshot corrente (mai null — ritorna [StreakSnapshot.empty] se mai
  /// incrementata).
  Future<StreakSnapshot> current(StreakId id) async {
    final row = await _dao.getState(id.key);
    if (row == null) return StreakSnapshot.empty(id);
    return StreakSnapshot(
      id: id,
      currentCount: row.currentCount,
      longest: row.longest,
      lastIncrementedDay: row.lastIncrementedDay,
    );
  }

  /// Stream reattivo dello snapshot di una streak.
  Stream<StreakSnapshot> watch(StreakId id) =>
      _dao.watchState(id.key).map((row) {
        if (row == null) return StreakSnapshot.empty(id);
        return StreakSnapshot(
          id: id,
          currentCount: row.currentCount,
          longest: row.longest,
          lastIncrementedDay: row.lastIncrementedDay,
        );
      });

  /// Per il display della streak "attuale": se l'ultimo incremento è
  /// precedente a ieri, la streak visibile deve essere 0 (persa). Questo
  /// metodo NON mutua il DB (lo aggiorneremo al prossimo evento
  /// rilevante), serve solo per render.
  static int effectiveCurrent(StreakSnapshot s, DateTime now) {
    final last = s.lastIncrementedDay;
    if (last == null) return 0;
    final today = dayKeyFor(now);
    final yesterday = dayKeyFor(DateTime(now.year, now.month, now.day - 1));
    if (last == today || last == yesterday) return s.currentCount;
    return 0;
  }
}
