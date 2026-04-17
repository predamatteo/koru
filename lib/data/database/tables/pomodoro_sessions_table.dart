import 'package:drift/drift.dart';

class PomodoroSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  IntColumn get workMs => integer()();
  IntColumn get breakMs => integer()();
  IntColumn get cycles => integer()();
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer()();
  BoolColumn get isStoppedManually => boolean().withDefault(const Constant(false))();
}
