import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

/// ARCH-04 — Contract test CROSS-RUNTIME (lato Dart).
///
/// Koru ha DUE runtime sullo stesso file `koru.db`: Drift (Dart) possiede lo
/// schema; il lato nativo Kotlin (`android/.../db/NativeDatabase.kt`) lo legge
/// con SQL grezzo e nomi hardcoded. Una rename/drop di colonna lato Drift
/// compila ma rompe l'enforcement nativo SILENZIOSAMENTE a runtime.
///
/// [kNativeSchemaContract] è la mappa (tabella → colonne) di cui il nativo
/// dipende — il MIRROR Dart di `DbSchema.kt`. Questo test apre lo schema VIVO
/// di Drift (`createAll()` via `AppDatabase.forTesting`), interroga
/// `PRAGMA table_info` per ogni tabella del contratto, e asserisce che ogni
/// colonna richiesta dal nativo esista DAVVERO nello schema Drift corrente.
///
/// → Se Drift rinomina/elimina una colonna su cui il nativo si appoggia, questo
///   test FALLISCE. È il pezzo che `DbSchemaContractTest.kt` (Kotlin) non può
///   coprire: quello verifica NativeDatabase vs DbSchema, questo verifica
///   DbSchema (replicato qui) vs lo schema reale di Drift.
///
/// LIMITE ONESTO (no codegen): [kNativeSchemaContract] e `DbSchema.kt` sono
/// mantenuti a mano e DEVONO restare in sync — SONO il contratto cross-runtime.
/// Questo test NON deriva la mappa dallo schema Drift né dal Kotlin: garantisce
/// solo che, DATO il contratto dichiarato, Drift lo soddisfi. Un rename
/// coordinato richiede di aggiornare ENTRAMBE le liste (qui + `DbSchema.kt`).
/// Un guard testuale sotto verifica almeno che le due liste di TABELLE non
/// divergano per dimenticanza grossolana.
///
/// MUST STAY IN SYNC WITH: android/app/src/main/kotlin/com/dev/koru/db/DbSchema.kt
const Map<String, List<String>> kNativeSchemaContract = {
  // profiles — getEnabledProfiles + join in getAllWebsiteRulesForEnabledProfiles
  'profiles': [
    'id',
    'title',
    'type_combinations',
    'on_conditions',
    'operator',
    'day_flags',
    'block_notifications',
    'block_launch',
    'is_enabled',
    'is_locked',
    'on_until',
    'locked_until',
    'paused_until',
    'blocking_mode',
    'block_unsupported_browsers',
    'block_adult_content',
    'color_hex',
    'emoji',
  ],
  // app_profile_relations — getAppRelationsForProfile
  'app_profile_relations': [
    'package_name',
    'profile_id',
    'is_enabled',
    'overlay_config_json',
    'blocked_sections_json',
  ],
  // intervals — getIntervalsForProfile
  'intervals': [
    'id',
    'profile_id',
    'from_minutes',
    'to_minutes',
    'is_enabled',
  ],
  // usage_limits — getUsageLimitsForProfile + updateUsedCount
  'usage_limits': [
    'id',
    'profile_id',
    'period_type',
    'limit_type',
    'last_reset_time',
    'allowed_count',
    'used_count',
  ],
  // website_rules — getWebsiteRulesForProfile + getAllWebsiteRulesForEnabledProfiles
  'website_rules': [
    'id',
    'profile_id',
    'name',
    'blocking_type',
    'is_anywhere_in_url',
    'is_enabled',
  ],
  // wifi_networks — getWifiSsidsByProfile
  'wifi_networks': [
    'profile_id',
    'ssid',
  ],
  // adult_content_sites — isAdultContentSite
  'adult_content_sites': [
    'domain',
  ],
  // block_sessions — insertBlockSession
  'block_sessions': [
    'name',
    'timestamp',
  ],
  // restricted_access_events — insertRestrictedAccessEvent
  'restricted_access_events': [
    'occurred_at',
    'day_start_date',
    'package_name',
    'event_type',
    'restriction_type',
  ],
  // intention_usage_events — insertIntentionEvent
  'intention_usage_events': [
    'occurred_at',
    'day_start_date',
    'package_name',
    'intention_name',
  ],
  // focus_usage_events — insertFocusUsageEvent
  'focus_usage_events': [
    'occurred_at',
    'day_start_date',
    'duration_in_ms',
  ],
};

void main() {
  group('DB schema cross-runtime contract (ARCH-04)', () {
    late AppDatabase db;

    setUp(() {
      // forTesting + NativeDatabase.memory() materializza lo schema reale via
      // MigrationStrategy.onCreate (createAll) — è esattamente lo schema che
      // Drift produrrebbe on-device alla versione corrente.
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    /// Legge i nomi colonna reali di [table] dallo schema Drift vivo.
    Future<Set<String>> liveColumns(String table) async {
      // PRAGMA table_info(<table>) → una riga per colonna, campo `name`.
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    test('ogni tabella del contratto esiste nello schema Drift', () async {
      final names = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final liveTables = names.map((r) => r.read<String>('name')).toSet();
      for (final table in kNativeSchemaContract.keys) {
        expect(
          liveTables,
          contains(table),
          reason: 'Il nativo (DbSchema.kt) dipende dalla tabella "$table" ma '
              'non esiste piu\' nello schema Drift. Se l\'hai rinominata/rimossa '
              'aggiorna NativeDatabase.kt + DbSchema.kt + questa mappa.',
        );
      }
    });

    test('ogni colonna richiesta dal nativo esiste nella sua tabella Drift',
        () async {
      final missing = <String>[];
      for (final entry in kNativeSchemaContract.entries) {
        final table = entry.key;
        final live = await liveColumns(table);
        for (final col in entry.value) {
          if (!live.contains(col)) {
            missing.add('$table.$col');
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'Colonne richieste dal nativo (DbSchema.kt) ma assenti dallo '
            'schema Drift corrente: $missing. Una rawQuery nativa su queste '
            'fallirebbe a runtime ⇒ enforcement spento silenziosamente. '
            'Riallinea NativeDatabase.kt + DbSchema.kt + kNativeSchemaContract '
            '(e aggiungi la migrazione Drift se e\' un rename).',
      );
    });

    test(
        'sanity: una colonna inventata NON e\' nello schema (il PRAGMA discrimina)',
        () async {
      // Guard meta: se il PRAGMA tornasse sempre vuoto/tutto, il test sopra
      // sarebbe un falso-verde. Verifichiamo che discrimini davvero.
      final live = await liveColumns('profiles');
      expect(live, contains('paused_until'));
      expect(live, isNot(contains('paused_until_does_not_exist')));
    });
  });
}
