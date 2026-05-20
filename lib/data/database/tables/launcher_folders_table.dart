import 'package:drift/drift.dart';

/// Cartelle per organizzare le app preferite nella home del launcher Koru.
///
/// `orderIndex` condivide lo spazio di ordinamento "top-level" con i
/// [Favorites] sciolti (quelli con `folderId == null`): la home del launcher
/// interlaccia app singole e cartelle in un'unica lista riordinabile, quindi
/// app-sciolte e cartelle pescano dallo stesso intervallo di indici 0..N-1.
class LauncherFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get orderIndex => integer()();
}
