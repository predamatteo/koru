import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

/// Migrazione v4 → v5: rimozione della tab Focus (quick block + pomodoro).
///
/// È l'unica migrazione DISTRUTTIVA dello schema — fa `DROP TABLE` invece di
/// aggiungere — quindi merita un test suo: un DROP che non parte lascia due
/// tabelle orfane sui device aggiornati, e un DROP senza `IF EXISTS` fa
/// fallire l'apertura del DB (e quindi il boot) su chi non ha mai
/// materializzato `pomodoro_sessions`, che era dichiarata ma mai usata.
void main() {
  group('migrazione v4 → v5 (rimozione tab Focus)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<bool> tableExists(String name) async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable<String>(name)],
          )
          .get();
      return rows.isNotEmpty;
    }

    Future<void> runUpgrade({required int from}) =>
        db.migration.onUpgrade(db.createMigrator(), from, 5);

    test('lo schema corrente è alla versione 5', () {
      expect(db.schemaVersion, 5);
    });

    test('lo schema nuovo non crea più le tabelle del focus', () async {
      // Forza l'apertura (onCreate) prima di interrogare sqlite_master.
      await db.getAllProfiles();

      expect(await tableExists('focus_usage_events'), isFalse);
      expect(await tableExists('pomodoro_sessions'), isFalse);
    });

    test('droppa entrambe le tabelle quando esistono', () async {
      await db.customStatement(
        'CREATE TABLE focus_usage_events ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'occurred_at INTEGER NOT NULL, '
        'day_start_date TEXT NOT NULL, '
        'duration_in_ms INTEGER NOT NULL)',
      );
      await db.customStatement(
        'CREATE TABLE pomodoro_sessions ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER NOT NULL)',
      );
      // Righe storiche presenti: il DROP deve portarsele via senza errori.
      await db.customStatement(
        "INSERT INTO focus_usage_events (occurred_at, day_start_date, "
        "duration_in_ms) VALUES (1, '2026-01-01', 60000)",
      );
      expect(await tableExists('focus_usage_events'), isTrue);
      expect(await tableExists('pomodoro_sessions'), isTrue);

      await runUpgrade(from: 4);

      expect(await tableExists('focus_usage_events'), isFalse);
      expect(await tableExists('pomodoro_sessions'), isFalse);
    });

    test('è idempotente: rieseguirla su un DB già migrato non lancia', () async {
      await runUpgrade(from: 4);
      await runUpgrade(from: 4);

      expect(await tableExists('focus_usage_events'), isFalse);
    });

    test(
        'non lancia quando pomodoro_sessions non è mai stata materializzata',
        () async {
      // Il caso reale: la tabella era dichiarata in @DriftDatabase ma nessuna
      // query la toccava. Senza `IF EXISTS` qui il boot fallirebbe.
      await db.customStatement(
        'CREATE TABLE focus_usage_events ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'occurred_at INTEGER NOT NULL)',
      );

      await runUpgrade(from: 4);

      expect(await tableExists('focus_usage_events'), isFalse);
    });
  });
}

// NOTA: non c'è un test per il salto da uno schema più vecchio (es. v2 → v5).
// `runUpgrade(from: 2)` rieseguirebbe anche gli step v2/v3/v4 contro un DB
// creato con lo schema CORRENTE, e `addColumn(favorites.folderId)` fallirebbe
// perché quella colonna c'è già. Verificarlo davvero richiede gli snapshot di
// schema di `drift_dev` (cartella `drift_schemas/`), che questo progetto non
// genera. Il guard `if (from < 5)` copre comunque i salti per costruzione.
