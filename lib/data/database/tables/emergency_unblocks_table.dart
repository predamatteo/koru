import 'package:drift/drift.dart';

class EmergencyUnblocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get timestamp => integer()();
}
