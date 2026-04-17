import 'package:drift/drift.dart';
import 'applications_table.dart';

/// App preferite nella home del launcher Koru. orderIndex per reordering drag-and-drop.
/// FK su Applications garantisce pulizia automatica su uninstall.
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get packageName =>
      text().references(Applications, #packageName, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {packageName},
      ];
}
