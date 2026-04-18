import 'package:drift/drift.dart';

/// Traccia gli achievement sbloccati dall'utente (one-shot).
/// Il catalogo è statico in Dart (id stabili tipo "focus_first",
/// "monk_mode"), qui salviamo solo la riga con timestamp di unlock.
class AchievementsUnlocked extends Table {
  TextColumn get id => text()();
  IntColumn get unlockedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
