import 'package:drift/drift.dart';

/// Tracciamento sessioni focus/pomodoro completate (durata in ms).
class FocusUsageEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get occurredAt => integer()();
  TextColumn get dayStartDate => text()();
  IntColumn get durationInMs => integer()();
}
