import 'package:drift/drift.dart';
import 'profiles_table.dart';

/// Phase 2: WiFi SSID per attivazione profilo su rete.
class WifiNetworks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get ssid => text()();
}
