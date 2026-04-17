import 'package:drift/drift.dart';
import 'profiles_table.dart';

/// Finestra oraria in cui un profilo è attivo (in minuti from midnight).
/// fromMinutes > toMinutes implica cross-midnight (es. 22:00-06:00 = 1320-360).
class Intervals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get fromMinutes => integer()();
  IntColumn get toMinutes => integer()();
  IntColumn get parentId => integer().nullable()();
  BoolColumn get isAllDayAuto => boolean().withDefault(const Constant(false))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
}
