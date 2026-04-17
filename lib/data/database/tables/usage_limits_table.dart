import 'package:drift/drift.dart';
import 'profiles_table.dart';

/// Limite di utilizzo: N aperture o M minuti in un periodo (daily/weekly/monthly).
class UsageLimits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get periodType => integer().withDefault(const Constant(0))();
  IntColumn get limitType => integer().withDefault(const Constant(0))();
  IntColumn get lastResetTime => integer().withDefault(const Constant(0))();
  IntColumn get allowedCount => integer().withDefault(const Constant(0))();
  IntColumn get usedCount => integer().withDefault(const Constant(0))();
  IntColumn get originalAllowedCount => integer().withDefault(const Constant(0))();
}
