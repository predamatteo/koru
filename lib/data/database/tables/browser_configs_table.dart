import 'package:drift/drift.dart';

/// Config di detection URL bar per diversi browser (Chrome, Firefox, Brave, ecc.).
class BrowserConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get packageName => text()();
  TextColumn get viewId => text()();
  IntColumn get viewType => integer().withDefault(const Constant(0))();
  BoolColumn get clearUrl => boolean().withDefault(const Constant(true))();
  TextColumn get detectionMethod => text().withDefault(const Constant('VIEW_ID'))();
  TextColumn get extractionMethod => text().withDefault(const Constant('TEXT'))();
  TextColumn get clickToOpenViewId => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {packageName, viewId},
      ];
}
