import 'package:drift/drift.dart';

class UsedBackdoorCodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  IntColumn get usedAt => integer()();
}
