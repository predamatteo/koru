import 'package:drift/drift.dart';

/// Log evento di blocco/skip. eventType: 0=BLOCK_TRIGGERED, 1=BLOCK_SKIPPED.
/// restrictionType: 0=APP, 1=SECTION, 2=WEBSITE, 3=USAGE_LIMIT, 4=FOCUS_MODE.
class RestrictedAccessEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get occurredAt => integer()();
  TextColumn get dayStartDate => text()();
  TextColumn get packageName => text()();
  IntColumn get eventType => integer()();
  IntColumn get restrictionType => integer()();
}
