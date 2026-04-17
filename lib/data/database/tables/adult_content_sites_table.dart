import 'package:drift/drift.dart';

class AdultContentSites extends Table {
  TextColumn get domain => text()();

  @override
  Set<Column> get primaryKey => {domain};
}
