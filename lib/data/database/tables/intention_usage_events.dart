import 'package:drift/drift.dart';

/// Tracciamento intenzioni selezionate dall'utente prima di aprire un'app bloccata.
class IntentionUsageEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get occurredAt => integer()();
  TextColumn get dayStartDate => text()();
  TextColumn get packageName => text()();
  TextColumn get intentionName => text()();
}
