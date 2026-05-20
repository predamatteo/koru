import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/achievements_dao.dart';
import 'daos/focus_usage_events_dao.dart';
import 'daos/intention_usage_events_dao.dart';
import 'daos/journal_dao.dart';
import 'daos/restricted_access_events_dao.dart';
import 'daos/streaks_dao.dart';
import 'tables/achievements_unlocked_table.dart';
import 'tables/journal_entries_table.dart';
import 'tables/adult_content_sites_table.dart';
import 'tables/app_profile_relations_table.dart';
import 'tables/applications_table.dart';
import 'tables/block_sessions_table.dart';
import 'tables/blocking_configs_table.dart';
import 'tables/browser_configs_table.dart';
import 'tables/emergency_unblocks_table.dart';
import 'tables/favorites_table.dart';
import 'tables/focus_usage_events.dart';
import 'tables/geo_addresses_table.dart';
import 'tables/intention_usage_events.dart';
import 'tables/intervals_table.dart';
import 'tables/launcher_folders_table.dart';
import 'tables/mood_check_ins_table.dart';
import 'tables/pomodoro_sessions_table.dart';
import 'tables/profiles_table.dart';
import 'tables/restricted_access_events.dart';
import 'tables/settings_table.dart';
import 'tables/streak_state_table.dart';
import 'tables/usage_limits_table.dart';
import 'tables/used_backdoor_codes_table.dart';
import 'tables/website_rules_table.dart';
import 'tables/wifi_networks_table.dart';

part 'app_database.g.dart';

/// Database Drift centrale di Koru.
///
/// 21 tabelle: 17 da app_blocker (con piccoli ritocchi su profiles/app_profile_relations),
/// 3 da ascent (restricted_access_events / intention_usage_events / focus_usage_events),
/// 1 nuova (favorites) per il launcher.
@DriftDatabase(
  tables: [
    Profiles,
    Applications,
    AppProfileRelations,
    WebsiteRules,
    Intervals,
    UsageLimits,
    GeoAddresses,
    WifiNetworks,
    BlockSessions,
    BrowserConfigs,
    AdultContentSites,
    PomodoroSessions,
    BlockingConfigs,
    MoodCheckIns,
    EmergencyUnblocks,
    UsedBackdoorCodes,
    Settings,
    RestrictedAccessEvents,
    IntentionUsageEvents,
    FocusUsageEvents,
    Favorites,
    LauncherFolders,
    AchievementsUnlocked,
    StreakState,
    JournalEntries,
  ],
  daos: [
    RestrictedAccessEventsDao,
    IntentionUsageEventsDao,
    FocusUsageEventsDao,
    AchievementsDao,
    StreaksDao,
    JournalDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // Indici per analytics queries (da ascent).
          await customStatement(
            'CREATE INDEX idx_rae_day ON restricted_access_events (day_start_date)',
          );
          await customStatement(
            'CREATE INDEX idx_rae_pkg_day ON restricted_access_events (package_name, day_start_date)',
          );
          await customStatement(
            'CREATE INDEX idx_iue_day ON intention_usage_events (day_start_date)',
          );
          await customStatement(
            'CREATE INDEX idx_iue_pkg_day ON intention_usage_events (package_name, day_start_date)',
          );
          await customStatement(
            'CREATE INDEX idx_fue_day ON focus_usage_events (day_start_date)',
          );

          // Seed default blocking overlay config.
          await into(blockingConfigs).insert(
            BlockingConfigsCompanion.insert(
              id: 'default',
              customTitle: const Value('Take a breath'),
              customSubtitle: const Value('This app is paused by your Koru profile.'),
              customExitButtonText: const Value('Go back'),
              customColorHex: const Value('#A85449'),
            ),
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: achievements & streaks (Phase 2).
            await m.createTable(achievementsUnlocked);
            await m.createTable(streakState);
          }
          if (from < 3) {
            // v3: journaling (Phase 2).
            await m.createTable(journalEntries);
          }
          if (from < 4) {
            // v4: cartelle per le app preferite del launcher. Additiva: la
            // colonna folderId nasce NULL su tutti i favoriti esistenti, che
            // restano quindi "sciolti" nella home col loro orderIndex attuale.
            // Ordine obbligato: prima la tabella referenziata, poi la FK.
            await m.createTable(launcherFolders);
            await m.addColumn(favorites, favorites.folderId);
          }
        },
      );

  // --- Profile queries ---
  Future<List<Profile>> getAllProfiles() => select(profiles).get();
  Stream<List<Profile>> watchAllProfiles() => select(profiles).watch();
  Future<Profile?> getProfileById(int id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<int> insertProfile(ProfilesCompanion profile) =>
      into(profiles).insert(profile);
  Future<bool> updateProfile(ProfilesCompanion profile) =>
      update(profiles).replace(profile);
  Future<int> deleteProfile(int id) =>
      (delete(profiles)..where((t) => t.id.equals(id))).go();

  // --- Application queries ---
  Future<List<Application>> getAllApplications() => (select(applications)
        ..orderBy([(a) => OrderingTerm.asc(a.labelForSearch)]))
      .get();
  Stream<List<Application>> watchAllApplications() => (select(applications)
        ..orderBy([(a) => OrderingTerm.asc(a.labelForSearch)]))
      .watch();
  Future<void> upsertApplication(ApplicationsCompanion app) =>
      into(applications).insertOnConflictUpdate(app);

  // --- App-Profile relation queries ---
  Future<List<AppProfileRelation>> getAppsForProfile(int profileId) =>
      (select(appProfileRelations)..where((r) => r.profileId.equals(profileId)))
          .get();
  Stream<List<AppProfileRelation>> watchAppsForProfile(int profileId) =>
      (select(appProfileRelations)..where((r) => r.profileId.equals(profileId)))
          .watch();
  Future<void> setAppsForProfile(
    int profileId,
    List<String> packageNames,
  ) async {
    // Non-destructive: preserva eventuali blockedSectionsJson e
    // overlayConfigJson per pkg che hanno config in-app o overlay
    // custom anche quando l'utente non li blocca interamente.
    // - pkg presente in lista: ensure isEnabled=true (insert se non
    //   esiste, update isEnabled se esiste).
    // - pkg non in lista: se relation ha sections o overlay config →
    //   set isEnabled=false (mantieni la config); altrimenti elimina.
    await transaction(() async {
      final wanted = packageNames.toSet();
      final existing = await (select(appProfileRelations)
            ..where((r) => r.profileId.equals(profileId)))
          .get();
      for (final rel in existing) {
        if (wanted.contains(rel.packageName)) {
          if (!rel.isEnabled) {
            await (update(appProfileRelations)
                  ..where((r) => r.id.equals(rel.id)))
                .write(const AppProfileRelationsCompanion(
                  isEnabled: Value(true),
                ));
          }
          wanted.remove(rel.packageName);
        } else {
          final hasConfig = (rel.blockedSectionsJson?.trim().isNotEmpty ??
                  false) ||
              (rel.overlayConfigJson?.trim().isNotEmpty ?? false);
          if (hasConfig) {
            // Mantieni la riga ma disattiva il blocco "intero".
            if (rel.isEnabled) {
              await (update(appProfileRelations)
                    ..where((r) => r.id.equals(rel.id)))
                  .write(const AppProfileRelationsCompanion(
                    isEnabled: Value(false),
                  ));
            }
          } else {
            await (delete(appProfileRelations)
                  ..where((r) => r.id.equals(rel.id)))
                .go();
          }
        }
      }
      // wanted contiene ora solo i pkg "nuovi" (non avevano relation).
      for (final pkg in wanted) {
        await into(appProfileRelations).insert(
          AppProfileRelationsCompanion.insert(
            profileId: profileId,
            packageName: pkg,
            isEnabled: const Value(true),
          ),
        );
      }
    });
  }

  /// Scrive `blockedSectionsJson` per la relation (profileId, packageName)
  /// SOLO se la relation esiste e il campo è attualmente null/vuoto.
  /// Non sovrascrive scelte esplicite dell'utente.
  Future<void> setDefaultBlockedSectionsIfEmpty({
    required int profileId,
    required String packageName,
    required String json,
  }) async {
    final rel = await (select(appProfileRelations)
          ..where((r) =>
              r.profileId.equals(profileId) &
              r.packageName.equals(packageName))
          ..limit(1))
        .getSingleOrNull();
    if (rel == null) return;
    if ((rel.blockedSectionsJson?.trim().isNotEmpty ?? false)) return;
    await (update(appProfileRelations)..where((r) => r.id.equals(rel.id)))
        .write(AppProfileRelationsCompanion(blockedSectionsJson: Value(json)));
  }

  // --- Website rule queries ---
  Future<List<WebsiteRule>> getWebsiteRulesForProfile(int profileId) =>
      (select(websiteRules)..where((r) => r.profileId.equals(profileId))).get();

  // --- Interval queries ---
  Future<List<Interval>> getIntervalsForProfile(int profileId) =>
      (select(intervals)..where((i) => i.profileId.equals(profileId))).get();

  // --- Wifi network queries (Phase 2) ---
  Future<List<WifiNetwork>> getWifisForProfile(int profileId) =>
      (select(wifiNetworks)..where((w) => w.profileId.equals(profileId))).get();

  Future<void> setWifisForProfile(int profileId, List<String> ssids) async {
    await transaction(() async {
      await (delete(wifiNetworks)..where((w) => w.profileId.equals(profileId)))
          .go();
      for (final ssid in ssids) {
        if (ssid.trim().isEmpty) continue;
        await into(wifiNetworks).insert(
          WifiNetworksCompanion.insert(
            profileId: profileId,
            ssid: ssid.trim(),
          ),
        );
      }
    });
  }

  // --- Usage limit queries ---
  Future<List<UsageLimit>> getUsageLimitsForProfile(int profileId) =>
      (select(usageLimits)..where((u) => u.profileId.equals(profileId))).get();

  // --- Block session queries ---
  Future<int> insertBlockSession(String name, int timestamp) => into(blockSessions)
      .insert(BlockSessionsCompanion.insert(name: name, timestamp: timestamp));
  Future<List<BlockSession>> getBlockSessionsInRange(int startMs, int endMs) =>
      (select(blockSessions)
            ..where(
              (s) => s.timestamp.isBiggerOrEqualValue(startMs) &
                  s.timestamp.isSmallerThanValue(endMs),
            ))
          .get();

  // --- Settings KV queries ---
  Future<String?> getSetting(String key) async {
    final row =
        await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value),
    );
  }

  // --- Mood queries ---
  Future<MoodCheckIn?> getMoodForDate(String day) =>
      (select(moodCheckIns)..where((m) => m.day.equals(day))).getSingleOrNull();
  Future<int> upsertMood(MoodCheckInsCompanion mood) =>
      into(moodCheckIns).insert(mood, mode: InsertMode.insertOrReplace);

  // --- Favorites queries (Koru launcher) ---
  Stream<List<Favorite>> watchFavorites() => (select(favorites)
        ..orderBy([(f) => OrderingTerm.asc(f.orderIndex)]))
      .watch();

  /// Stream dei favoriti CON label, risolto via join su `applications` (dove
  /// `addFavorite` salva sempre il label dell'app favoritata). Permette di
  /// renderizzare la lista favoriti della home launcher SENZA dipendere dal
  /// lento `getInstalledApps` nativo (scan PackageManager + decode icone,
  /// 1-3s): la home mostra solo testo e il label vive gia' nel DB locale.
  /// Cosi' i favoriti compaiono subito al cold start e non spariscono durante
  /// un reload/dispose di installedAppsProvider (flicker ricorrente). Left
  /// join + fallback al packageName: anche se per qualche motivo manca la riga
  /// in `applications`, il favorito resta visibile (col package come label).
  Stream<List<({String packageName, String label, int? folderId, int orderIndex})>>
      watchFavoritesWithLabels() {
    final query = select(favorites).join([
      leftOuterJoin(
        applications,
        applications.packageName.equalsExp(favorites.packageName),
      ),
    ])
      ..orderBy([OrderingTerm.asc(favorites.orderIndex)]);
    return query.watch().map((rows) => rows.map((row) {
          final fav = row.readTable(favorites);
          final app = row.readTableOrNull(applications);
          return (
            packageName: fav.packageName,
            label: app?.label ?? fav.packageName,
            folderId: fav.folderId,
            orderIndex: fav.orderIndex,
          );
        }).toList(growable: false));
  }

  Future<List<Favorite>> getFavorites() => (select(favorites)
        ..orderBy([(f) => OrderingTerm.asc(f.orderIndex)]))
      .get();
  Future<void> addFavorite(
    String packageName, {
    String? label,
    int? folderId,
  }) async {
    // Garantisce che la riga in `applications` esista: la FK del favorito
    // punta lì e Drift 2.x ha foreign_keys=ON di default, quindi senza
    // questa upsert l'insert fallirebbe silenziosamente con FK violation
    // (insertOrIgnore NON copre FK, solo PK/UNIQUE).
    final resolvedLabel = label ?? packageName;
    await into(applications).insert(
      ApplicationsCompanion.insert(
        packageName: packageName,
        label: resolvedLabel,
        labelForSearch: resolvedLabel.toLowerCase(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    // Nuovo favorito: in coda allo spazio di ordinamento giusto. Se sciolto
    // (folderId == null) → spazio top-level (condiviso con le cartelle); se in
    // cartella → spazio interno alla cartella.
    final nextIndex = folderId == null
        ? await _nextTopLevelOrderIndex()
        : await _nextFolderOrderIndex(folderId);
    await into(favorites).insert(
      FavoritesCompanion.insert(
        packageName: packageName,
        orderIndex: nextIndex,
        folderId: Value(folderId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeFavorite(String packageName) => (delete(favorites)
        ..where((f) => f.packageName.equals(packageName)))
      .go();

  Future<void> reorderFavorites(List<String> orderedPackageNames) async {
    await transaction(() async {
      for (var i = 0; i < orderedPackageNames.length; i++) {
        await (update(favorites)
              ..where((f) => f.packageName.equals(orderedPackageNames[i])))
            .write(FavoritesCompanion(orderIndex: Value(i)));
      }
    });
  }

  // --- Launcher folders (cartelle dei preferiti) ---

  /// Prossimo orderIndex nello spazio "top-level": gli item visibili in home
  /// sono i favoriti sciolti (folderId == null) PIÙ tutte le cartelle, che
  /// condividono lo stesso intervallo di indici.
  Future<int> _nextTopLevelOrderIndex() async {
    final loose =
        await (select(favorites)..where((f) => f.folderId.isNull())).get();
    final folders = await select(launcherFolders).get();
    var max = -1;
    for (final f in loose) {
      if (f.orderIndex > max) max = f.orderIndex;
    }
    for (final d in folders) {
      if (d.orderIndex > max) max = d.orderIndex;
    }
    return max + 1;
  }

  /// Prossimo orderIndex DENTRO una cartella (spazio interno separato).
  Future<int> _nextFolderOrderIndex(int folderId) async {
    final inFolder = await (select(favorites)
          ..where((f) => f.folderId.equals(folderId)))
        .get();
    var max = -1;
    for (final f in inFolder) {
      if (f.orderIndex > max) max = f.orderIndex;
    }
    return max + 1;
  }

  Stream<List<LauncherFolder>> watchFolders() => (select(launcherFolders)
        ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
      .watch();

  Future<List<LauncherFolder>> getFolders() => (select(launcherFolders)
        ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
      .get();

  /// Crea una cartella in coda al top-level e ne ritorna l'id.
  Future<int> createFolder(String name) async {
    final idx = await _nextTopLevelOrderIndex();
    return into(launcherFolders)
        .insert(LauncherFoldersCompanion.insert(name: name, orderIndex: idx));
  }

  Future<void> renameFolder(int id, String name) =>
      (update(launcherFolders)..where((t) => t.id.equals(id)))
          .write(LauncherFoldersCompanion(name: Value(name)));

  /// Elimina una cartella SENZA perdere i suoi preferiti: prima li riporta nel
  /// top-level (folderId = null) con indici freschi in coda — i loro orderIndex
  /// erano relativi alla cartella e collidereberro col top-level — poi cancella
  /// la cartella. (Lo facciamo a mano invece di affidarci a onDelete:setNull
  /// proprio per riassegnare gli indici e non lasciare ordini incoerenti.)
  Future<void> deleteFolder(int id) async {
    await transaction(() async {
      final inFolder = await (select(favorites)
            ..where((f) => f.folderId.equals(id))
            ..orderBy([(f) => OrderingTerm.asc(f.orderIndex)]))
          .get();
      var next = await _nextTopLevelOrderIndex();
      for (final fav in inFolder) {
        await (update(favorites)..where((f) => f.id.equals(fav.id))).write(
          FavoritesCompanion(
            folderId: const Value(null),
            orderIndex: Value(next),
          ),
        );
        next++;
      }
      await (delete(launcherFolders)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Sposta un preferito in una cartella (`folderId` valorizzato) o lo riporta
  /// sciolto nella home (`folderId == null`), in coda allo spazio di destino.
  Future<void> setFavoriteFolder(String packageName, int? folderId) async {
    await transaction(() async {
      final nextIndex = folderId == null
          ? await _nextTopLevelOrderIndex()
          : await _nextFolderOrderIndex(folderId);
      await (update(favorites)..where((f) => f.packageName.equals(packageName)))
          .write(
        FavoritesCompanion(
          folderId: Value(folderId),
          orderIndex: Value(nextIndex),
        ),
      );
    });
  }

  /// Riordina gli item top-level della home (mix di app sciolte e cartelle).
  /// Ogni elemento ha ESATTAMENTE uno tra `packageName` (app sciolta) e
  /// `folderId` (cartella) valorizzato; l'indice di posizione diventa il nuovo
  /// orderIndex nello spazio condiviso.
  Future<void> reorderTopLevel(
    List<({String? packageName, int? folderId})> items,
  ) async {
    await transaction(() async {
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        if (it.packageName != null) {
          await (update(favorites)
                ..where((f) => f.packageName.equals(it.packageName!)))
              .write(FavoritesCompanion(orderIndex: Value(i)));
        } else if (it.folderId != null) {
          await (update(launcherFolders)..where((t) => t.id.equals(it.folderId!)))
              .write(LauncherFoldersCompanion(orderIndex: Value(i)));
        }
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'koru.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // Forziamo journal_mode=DELETE (no WAL) perché il blocking engine
        // legge il DB anche da Kotlin via android.database.sqlite. Le due
        // librerie SQLite distinte (sqlite3_flutter_libs lato Flutter vs
        // libsqlite di sistema lato Android) non condividono in modo
        // affidabile i file ausiliari `-shm`/`-wal` del WAL — produceva
        // SQLITE_IOERR_SHM* su qualsiasi SELECT (es. su intervals nei
        // watcher di profile_repository) appena Kotlin apriva il DB.
        // DELETE mode usa solo il file principale + un rollback journal
        // temporaneo, gestito via fcntl-locks compatibili con entrambe.
        rawDb.execute('PRAGMA journal_mode = DELETE;');
        rawDb.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}
