import '../database/app_database.dart';
import '../database/daos/achievements_dao.dart';

class AchievementsRepository {
  AchievementsRepository(this._dao);

  final AchievementsDao _dao;

  Future<Set<String>> getUnlockedIds() async {
    final rows = await _dao.getAllUnlocked();
    return rows.map((r) => r.id).toSet();
  }

  Stream<List<AchievementsUnlockedData>> watchAll() => _dao.watchAllUnlocked();

  Future<bool> isUnlocked(String id) => _dao.isUnlocked(id);

  /// Sblocca un achievement (idempotente: no-op se già sbloccato).
  /// Ritorna true se era un nuovo unlock.
  Future<bool> unlock(String id) async {
    if (await _dao.isUnlocked(id)) return false;
    await _dao.unlock(id);
    return true;
  }
}
