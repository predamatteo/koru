import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/achievements_dao.dart';
import 'daos/focus_usage_events_dao.dart';
import 'daos/intention_usage_events_dao.dart';
import 'daos/restricted_access_events_dao.dart';
import 'daos/streaks_dao.dart';
import 'tables/achievements_unlocked_table.dart';
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
    AchievementsUnlocked,
    StreakState,
  ],
  daos: [
    RestrictedAccessEventsDao,
    IntentionUsageEventsDao,
    FocusUsageEventsDao,
    AchievementsDao,
    StreaksDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

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
    await (delete(appProfileRelations)
          ..where((r) => r.profileId.equals(profileId)))
        .go();
    for (final pkg in packageNames) {
      await into(appProfileRelations).insert(
        AppProfileRelationsCompanion.insert(
          profileId: profileId,
          packageName: pkg,
        ),
      );
    }
  }

  // --- Website rule queries ---
  Future<List<WebsiteRule>> getWebsiteRulesForProfile(int profileId) =>
      (select(websiteRules)..where((r) => r.profileId.equals(profileId))).get();

  // --- Interval queries ---
  Future<List<Interval>> getIntervalsForProfile(int profileId) =>
      (select(intervals)..where((i) => i.profileId.equals(profileId))).get();

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
      into(moodCheckIns).insertOnConflictUpdate(mood);

  // --- Favorites queries (Koru launcher) ---
  Stream<List<Favorite>> watchFavorites() => (select(favorites)
        ..orderBy([(f) => OrderingTerm.asc(f.orderIndex)]))
      .watch();
  Future<List<Favorite>> getFavorites() => (select(favorites)
        ..orderBy([(f) => OrderingTerm.asc(f.orderIndex)]))
      .get();
  Future<void> addFavorite(String packageName) async {
    final existing = await (select(favorites)..limit(1)).get();
    final nextIndex = existing.isEmpty
        ? 0
        : (await (select(favorites)
                  ..orderBy([(f) => OrderingTerm.desc(f.orderIndex)])
                  ..limit(1))
                .getSingle())
                .orderIndex +
            1;
    await into(favorites).insert(
      FavoritesCompanion.insert(
        packageName: packageName,
        orderIndex: nextIndex,
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'koru.db'));
    return NativeDatabase.createInBackground(file);
  });
}
