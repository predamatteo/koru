import 'package:drift/drift.dart';
import 'profiles_table.dart';

class WebsiteRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get name => text()();
  IntColumn get blockingType => integer().withDefault(const Constant(0))();
  BoolColumn get isAnywhereInUrl => boolean().withDefault(const Constant(false))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
}
