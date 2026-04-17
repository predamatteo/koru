import 'package:drift/drift.dart';

/// Config globale dell'overlay di blocco (default riutilizzato se un profilo/app
/// non specifica overlayConfigJson proprio).
class BlockingConfigs extends Table {
  TextColumn get id => text()();
  IntColumn get configType => integer().withDefault(const Constant(0))();
  TextColumn get blockingMessage => text().withDefault(const Constant(''))();
  IntColumn get timeoutSeconds => integer().withDefault(const Constant(0))();
  TextColumn get customTitle => text().withDefault(const Constant(''))();
  TextColumn get customSubtitle => text().withDefault(const Constant(''))();
  TextColumn get customExitButtonText => text().withDefault(const Constant(''))();
  TextColumn get customColorHex => text().withDefault(const Constant('#A85449'))();

  @override
  Set<Column> get primaryKey => {id};
}
