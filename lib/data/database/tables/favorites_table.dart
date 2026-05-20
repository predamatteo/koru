import 'package:drift/drift.dart';
import 'applications_table.dart';
import 'launcher_folders_table.dart';

/// App preferite nella home del launcher Koru. orderIndex per reordering drag-and-drop.
/// FK su Applications garantisce pulizia automatica su uninstall.
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get packageName =>
      text().references(Applications, #packageName, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer()();

  /// Cartella di appartenenza nella home del launcher.
  ///
  /// - `null` → preferito "sciolto": `orderIndex` vive nello spazio top-level
  ///   (condiviso con le [LauncherFolders]).
  /// - valorizzato → preferito dentro la cartella: `orderIndex` è relativo agli
  ///   altri preferiti della stessa cartella.
  ///
  /// `onDelete: setNull` → eliminando una cartella i suoi preferiti tornano
  /// sciolti nella home invece di sparire (la rimozione cartella non deve mai
  /// cancellare app preferite).
  IntColumn get folderId => integer()
      .nullable()
      .references(LauncherFolders, #id, onDelete: KeyAction.setNull)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {packageName},
      ];
}
