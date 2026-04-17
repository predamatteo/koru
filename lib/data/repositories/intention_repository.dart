import '../database/app_database.dart';

/// Registra le intenzioni scelte dall'utente prima di aprire un'app bloccata.
/// Alimenta il dashboard "Top intentions" in Statistics (Step 12).
class IntentionRepository {
  IntentionRepository(this._db);

  final AppDatabase _db;

  Future<void> record({
    required String packageName,
    required String intention,
  }) async {
    final now = DateTime.now();
    final dayStart = _formatDay(now);
    await _db.intentionUsageEventsDao.insertEvent(
      IntentionUsageEventsCompanion.insert(
        occurredAt: now.millisecondsSinceEpoch,
        dayStartDate: dayStart,
        packageName: packageName,
        intentionName: intention,
      ),
    );
  }

  static String _formatDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
