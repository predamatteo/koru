import 'package:drift/drift.dart';

/// Generic key-value store per impostazioni persistenti lato Drift
/// (in alternativa a Hive, usato solo per settings legati al blocking).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
