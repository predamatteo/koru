import '../../domain/usecases/evaluate_achievements.dart';
import '../database/app_database.dart';
import '../database/daos/achievements_dao.dart';

/// Implementa [AchievementsGateway] (domain) — l'inversione di dipendenza fa
/// sì che il valutatore dipenda dall'astrazione, non da questa concreta.
class AchievementsRepository implements AchievementsGateway {
  AchievementsRepository(this._dao);

  final AchievementsDao _dao;

  @override
  Future<Set<String>> getUnlockedIds() async {
    final rows = await _dao.getAllUnlocked();
    return rows.map((r) => r.id).toSet();
  }

  Stream<List<AchievementsUnlockedData>> watchAll() => _dao.watchAllUnlocked();

  Future<bool> isUnlocked(String id) => _dao.isUnlocked(id);

  /// Sblocca un achievement (idempotente: no-op se già sbloccato).
  /// Ritorna true se era un nuovo unlock.
  @override
  Future<bool> unlock(String id) async {
    if (await _dao.isUnlocked(id)) return false;
    await _dao.unlock(id);
    return true;
  }
}
