import 'package:drift/drift.dart';

import '../database/app_database.dart';

class MoodRepository {
  MoodRepository(this._db);

  final AppDatabase _db;

  Future<MoodCheckIn?> getForToday() => _db.getMoodForDate(_todayKey());

  Future<void> upsertToday({required int mood, String? note, String? tagsJson}) =>
      _db.upsertMood(MoodCheckInsCompanion.insert(
        mood: mood,
        day: _todayKey(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        note: Value(note),
        tagsJson: Value(tagsJson),
      ));

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
