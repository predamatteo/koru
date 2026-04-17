import 'package:drift/drift.dart';
import 'profiles_table.dart';

/// Relazione M:N tra profilo e app bloccata/consentita.
///
/// Koru estende rispetto ad app_blocker con:
/// - overlayConfigJson: configurazione overlay personalizzato per-app-per-profilo
///   (colore, messaggio, countdown seconds, shakeEnabled, ecc.). JSON string.
/// - blockedSectionsJson: sezioni in-app bloccate (es. Reels/Stories per Instagram).
///   Utilizzabile SOLO se isEnabled=true (app non interamente bloccata).
class AppProfileRelations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get packageName => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get overlayConfigJson => text().nullable()();
  TextColumn get blockedSectionsJson => text().nullable()();
}
