import 'package:drift/drift.dart';
import 'profiles_table.dart';

/// Phase 2: geofence per attivazione profilo su location.
/// Schema già presente in MVP per evitare migrazioni future.
class GeoAddresses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get geofenceId => text()();
  IntColumn get radiusMeters => integer().withDefault(const Constant(200))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  BoolColumn get isInverted => boolean().withDefault(const Constant(false))();
  TextColumn get displayName => text().nullable()();
}
