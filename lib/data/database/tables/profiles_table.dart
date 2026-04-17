import 'package:drift/drift.dart';

/// Profile = insieme di regole di blocco attivate su condizioni (orario, giorni, usage).
///
/// Koru aggiunge rispetto ad app_blocker originale:
/// - colorHex: colore per badge profilo in UI
/// - presetId: id del preset originale (null se custom). Usato dagli onboarding presets.
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get typeCombinations => integer().withDefault(const Constant(0))();
  IntColumn get onConditions => integer().withDefault(const Constant(0))();
  IntColumn get operator => integer().withDefault(const Constant(0))();
  IntColumn get dayFlags => integer().withDefault(const Constant(127))();
  BoolColumn get blockNotifications => boolean().withDefault(const Constant(true))();
  BoolColumn get blockLaunch => boolean().withDefault(const Constant(true))();
  BoolColumn get addNewApplications => boolean().withDefault(const Constant(false))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  IntColumn get lastStartTime => integer().withDefault(const Constant(0))();
  IntColumn get onUntil => integer().withDefault(const Constant(0))();
  IntColumn get lockedUntil => integer().withDefault(const Constant(0))();
  IntColumn get lockAt => integer().withDefault(const Constant(0))();
  IntColumn get pausedUntil => integer().withDefault(const Constant(0))();
  IntColumn get blockingMode => integer().withDefault(const Constant(0))();
  TextColumn get emoji => text().withDefault(const Constant('NoIcon'))();
  BoolColumn get blockUnsupportedBrowsers => boolean().withDefault(const Constant(false))();
  BoolColumn get blockAdultContent => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get colorHex => text().withDefault(const Constant('#5C8262'))();
  IntColumn get presetId => integer().nullable()();
}
