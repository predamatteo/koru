import 'package:drift/drift.dart';

/// Catalogo delle app installate sul device (cache lato Flutter).
class Applications extends Table {
  TextColumn get packageName => text()();
  TextColumn get label => text()();
  TextColumn get labelForSearch => text()();
  BoolColumn get isUninstalled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {packageName};
}
