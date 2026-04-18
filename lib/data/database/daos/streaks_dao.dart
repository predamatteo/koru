import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/streak_state_table.dart';

part 'streaks_dao.g.dart';

@DriftAccessor(tables: [StreakState])
class StreaksDao extends DatabaseAccessor<AppDatabase> with _$StreaksDaoMixin {
  StreaksDao(super.db);

  Stream<StreakStateData?> watchState(String id) =>
      (select(streakState)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  Future<StreakStateData?> getState(String id) =>
      (select(streakState)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(StreakStateCompanion entry) =>
      into(streakState).insertOnConflictUpdate(entry);

  Stream<List<StreakStateData>> watchAll() => select(streakState).watch();
}
