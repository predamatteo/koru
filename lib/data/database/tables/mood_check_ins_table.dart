import 'package:drift/drift.dart';

/// Mood daily (1-5). Una riga per giorno (day = YYYY-MM-DD, UNIQUE).
class MoodCheckIns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mood => integer()();
  TextColumn get day => text().unique()();
  IntColumn get createdAt => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get tagsJson => text().nullable()();
}
