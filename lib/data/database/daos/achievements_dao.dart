import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/achievements_unlocked_table.dart';

part 'achievements_dao.g.dart';

@DriftAccessor(tables: [AchievementsUnlocked])
class AchievementsDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementsDaoMixin {
  AchievementsDao(super.db);

  Stream<List<AchievementsUnlockedData>> watchAllUnlocked() =>
      select(achievementsUnlocked).watch();

  Future<List<AchievementsUnlockedData>> getAllUnlocked() =>
      select(achievementsUnlocked).get();

  Future<bool> isUnlocked(String id) async {
    final row = await (select(achievementsUnlocked)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null;
  }

  /// Idempotente: se l'id esiste non sovrascrive (preserva timestamp
  /// originale di unlock).
  Future<void> unlock(String id) async {
    await into(achievementsUnlocked).insert(
      AchievementsUnlockedCompanion.insert(
        id: id,
        unlockedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
