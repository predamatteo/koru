import 'package:drift/drift.dart';

/// Log di un profilo attivato (per insights).
class BlockSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get timestamp => integer()();
}
