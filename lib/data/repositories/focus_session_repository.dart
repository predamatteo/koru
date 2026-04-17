import '../database/app_database.dart';

/// Logs focus sessions (pomodoro + quick block) into `focus_usage_events`.
class FocusSessionRepository {
  FocusSessionRepository(this._db);

  final AppDatabase _db;

  Future<void> recordCompletedSession(Duration duration) async {
    final now = DateTime.now();
    await _db.focusUsageEventsDao.insertEvent(
      FocusUsageEventsCompanion.insert(
        occurredAt: now.millisecondsSinceEpoch,
        dayStartDate: _formatDay(now),
        durationInMs: duration.inMilliseconds,
      ),
    );
  }

  static String _formatDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
