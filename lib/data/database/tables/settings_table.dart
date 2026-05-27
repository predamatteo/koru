import 'package:drift/drift.dart';

/// Generic key-value store lato Drift.
///
/// Reserved/unused — nessun caller a runtime (vedi review ARCH-08). Gli
/// accessor `getSetting`/`setSetting` sono stati rimossi perche' morti; la
/// tabella resta definita (nessuna migrazione distruttiva solo per cleanup):
/// il KV applicativo passa per Hive/shared_preferences. Non aggiungere
/// scritture qui senza prima consolidare i meccanismi KV (debito ARCH-08).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
