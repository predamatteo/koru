import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

void main() {
  group('AppDatabase extended', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    // ─── Favorites edge cases ───────────────────────────────────────────────
    group('favorites', () {
      test('addFavorite auto-creates the Applications row for an unknown pkg',
          () async {
        // No insert into `applications` first: addFavorite must upsert one
        // (FK violation would otherwise abort).
        await db.addFavorite('com.brand.new', label: 'Brand New');

        final apps =
            await db.getAllApplications().then((l) => l.map((a) => a.packageName));
        expect(apps, contains('com.brand.new'));

        final favs = await db.getFavorites();
        expect(favs.single.packageName, 'com.brand.new');
        expect(favs.single.orderIndex, 0);
      });

      test('addFavorite without label uses package name as label fallback',
          () async {
        await db.addFavorite('com.unlabeled');
        final app = await (db.select(db.applications)
              ..where((a) => a.packageName.equals('com.unlabeled')))
            .getSingle();
        expect(app.label, 'com.unlabeled');
        expect(app.labelForSearch, 'com.unlabeled');
      });

      test(
          'addFavorite called twice for the same package keeps a single row '
          '(insertOrIgnore)', () async {
        await db.addFavorite('com.x');
        await db.addFavorite('com.x');

        final favs = await db.getFavorites();
        expect(favs, hasLength(1));
      });

      test('addFavorite assigns monotonically increasing orderIndex',
          () async {
        await db.addFavorite('com.a');
        await db.addFavorite('com.b');
        await db.addFavorite('com.c');

        final favs = await db.getFavorites();
        expect(favs.map((f) => f.orderIndex), [0, 1, 2]);
      });

      test('removeFavorite on a non-favorited package is a graceful no-op',
          () async {
        await db.addFavorite('com.kept');

        // Different package — should not throw nor remove anything.
        await db.removeFavorite('com.never_added');

        final favs = await db.getFavorites();
        expect(favs, hasLength(1));
        expect(favs.single.packageName, 'com.kept');
      });

      test('reorderFavorites ignores packages that are not in the favorites list',
          () async {
        await db.addFavorite('com.a');
        await db.addFavorite('com.b');
        await db.addFavorite('com.c');

        // List contains a "ghost" package — it should be ignored.
        await db.reorderFavorites(['com.b', 'com.ghost', 'com.a']);

        final favs = await db.getFavorites();
        // Order = orderIndex. After the rewrite:
        // com.b → 0, com.ghost → 1 (no-op), com.a → 2, com.c is untouched (=2).
        // SQL ORDER BY orderIndex ASC: com.b (0), com.a (2), com.c (2).
        final pkgs = favs.map((f) => f.packageName).toList();
        expect(pkgs.first, 'com.b');
        expect(pkgs, containsAll(['com.a', 'com.b', 'com.c']));
        expect(pkgs.length, 3);
      });

      test('reorderFavorites with a partial list does not delete missing favorites',
          () async {
        await db.addFavorite('com.a');
        await db.addFavorite('com.b');
        await db.addFavorite('com.c');

        await db.reorderFavorites(['com.c']);
        final favs = await db.getFavorites();
        // All three are still there — only the new index for com.c changed.
        expect(favs.map((f) => f.packageName).toSet(),
            {'com.a', 'com.b', 'com.c'});
      });

      test('watchFavorites re-emits after addFavorite', () async {
        final stream = db.watchFavorites();
        final emissions = <int>[];
        final sub = stream.listen((list) => emissions.add(list.length));

        await db.addFavorite('com.a');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions.first, 0);
        expect(emissions.last, 1);
      });
    });

    // ─── Profiles with all fields populated ────────────────────────────────
    group('profiles full schema', () {
      test('insertProfile + getProfileById preserves every populated field',
          () async {
        final id = await db.insertProfile(
          ProfilesCompanion.insert(
            title: const Value('Deep Work'),
            typeCombinations: const Value(1 | 16), // time + usageLimit
            dayFlags: const Value(31), // weekdays
            blockingMode: const Value(1), // allowlist
            emoji: const Value('🎯'),
            colorHex: const Value('#8A6D52'),
            blockAdultContent: const Value(true),
            blockUnsupportedBrowsers: const Value(true),
            isEnabled: const Value(true),
            sortOrder: const Value(7),
            presetId: const Value(42),
            pausedUntil: const Value(1_700_000_000_000),
          ),
        );

        final fetched = await db.getProfileById(id);
        expect(fetched, isNotNull);
        expect(fetched!.title, 'Deep Work');
        expect(fetched.typeCombinations, 17);
        expect(fetched.dayFlags, 31);
        expect(fetched.blockingMode, 1);
        expect(fetched.emoji, '🎯');
        expect(fetched.colorHex, '#8A6D52');
        expect(fetched.blockAdultContent, isTrue);
        expect(fetched.blockUnsupportedBrowsers, isTrue);
        expect(fetched.isEnabled, isTrue);
        expect(fetched.sortOrder, 7);
        expect(fetched.presetId, 42);
        expect(fetched.pausedUntil, 1_700_000_000_000);
      });

      test('default emoji is "NoIcon" and default colorHex is "#5C8262"',
          () async {
        final id = await db.insertProfile(
          ProfilesCompanion.insert(title: const Value('Plain')),
        );
        final p = await db.getProfileById(id);
        expect(p!.emoji, 'NoIcon');
        expect(p.colorHex, '#5C8262');
      });

      test('default dayFlags is 127 (allDays)', () async {
        final id = await db.insertProfile(
          ProfilesCompanion.insert(title: const Value('Default Days')),
        );
        final p = await db.getProfileById(id);
        expect(p!.dayFlags, 127);
      });
    });

    // ─── AppProfileRelations ───────────────────────────────────────────────
    group('app-profile relations', () {
      Future<int> seedProfile([String title = 'P']) => db.insertProfile(
            ProfilesCompanion.insert(title: Value(title)),
          );

      test('setAppsForProfile inserts new relations for new packages',
          () async {
        final id = await seedProfile();
        await db.setAppsForProfile(id, ['com.a', 'com.b', 'com.c']);

        final rels = await db.getAppsForProfile(id);
        expect(
          rels.map((r) => r.packageName).toSet(),
          {'com.a', 'com.b', 'com.c'},
        );
        expect(rels.every((r) => r.isEnabled), isTrue);
      });

      test('setAppsForProfile removes packages no longer in the list',
          () async {
        final id = await seedProfile();
        await db.setAppsForProfile(id, ['com.a', 'com.b']);
        await db.setAppsForProfile(id, ['com.a']);

        final rels = await db.getAppsForProfile(id);
        expect(rels.map((r) => r.packageName), ['com.a']);
      });

      test(
          'setAppsForProfile re-enables a relation that had been disabled '
          '(preserved because it had blockedSectionsJson)', () async {
        final id = await seedProfile();
        // Insert manually with sections so that removing from the list
        // keeps the row but disables it.
        await db.into(db.appProfileRelations).insert(
              AppProfileRelationsCompanion.insert(
                profileId: id,
                packageName: 'com.with.sections',
                blockedSectionsJson:
                    const Value('{"sections":["INSTAGRAM_REELS"]}'),
              ),
            );

        // Remove → must keep (because has sections) and set isEnabled=false.
        await db.setAppsForProfile(id, const []);
        var rel = (await db.getAppsForProfile(id)).single;
        expect(rel.isEnabled, isFalse);
        expect(rel.blockedSectionsJson, isNotNull);

        // Re-add → must flip back to isEnabled=true, sections preserved.
        await db.setAppsForProfile(id, ['com.with.sections']);
        rel = (await db.getAppsForProfile(id)).single;
        expect(rel.isEnabled, isTrue);
        expect(rel.blockedSectionsJson,
            '{"sections":["INSTAGRAM_REELS"]}');
      });

      test('setDefaultBlockedSectionsIfEmpty only writes when current is empty',
          () async {
        final id = await seedProfile();
        // Relation exists but no sections yet.
        await db.into(db.appProfileRelations).insert(
              AppProfileRelationsCompanion.insert(
                profileId: id,
                packageName: 'com.instagram.android',
              ),
            );
        await db.setDefaultBlockedSectionsIfEmpty(
          profileId: id,
          packageName: 'com.instagram.android',
          json: '{"sections":["INSTAGRAM_REELS"]}',
        );
        var rel = (await db.getAppsForProfile(id)).single;
        expect(rel.blockedSectionsJson, '{"sections":["INSTAGRAM_REELS"]}');

        // Calling again must NOT overwrite the existing JSON.
        await db.setDefaultBlockedSectionsIfEmpty(
          profileId: id,
          packageName: 'com.instagram.android',
          json: '{"sections":["INSTAGRAM_STORIES"]}',
        );
        rel = (await db.getAppsForProfile(id)).single;
        expect(rel.blockedSectionsJson, '{"sections":["INSTAGRAM_REELS"]}');
      });

      test('setDefaultBlockedSectionsIfEmpty is a no-op if relation missing',
          () async {
        // No relation exists for this (profile, pkg) pair → no throw, no row.
        await db.setDefaultBlockedSectionsIfEmpty(
          profileId: 9999,
          packageName: 'com.does.not.exist',
          json: '{"sections":["X"]}',
        );

        final rels = await db.getAppsForProfile(9999);
        expect(rels, isEmpty);
      });

      test('watchAppsForProfile emits the current set initially', () async {
        final id = await seedProfile();
        await db.setAppsForProfile(id, ['com.a']);

        final list = await db.watchAppsForProfile(id).first;
        expect(list.map((r) => r.packageName), ['com.a']);
      });
    });

    // ─── WebsiteRules ──────────────────────────────────────────────────────
    group('website rules', () {
      test('insert + getWebsiteRulesForProfile + delete roundtrip', () async {
        final id = await db.insertProfile(
            ProfilesCompanion.insert(title: const Value('P')));
        await db.into(db.websiteRules).insert(
              WebsiteRulesCompanion.insert(
                profileId: id,
                name: 'reddit.com',
                isAnywhereInUrl: const Value(true),
              ),
            );
        final rules = await db.getWebsiteRulesForProfile(id);
        expect(rules, hasLength(1));
        expect(rules.single.name, 'reddit.com');
        expect(rules.single.isAnywhereInUrl, isTrue);

        await (db.delete(db.websiteRules)
              ..where((r) => r.id.equals(rules.single.id)))
            .go();
        expect(await db.getWebsiteRulesForProfile(id), isEmpty);
      });
    });

    // ─── Intervals (cross-midnight) ────────────────────────────────────────
    group('intervals', () {
      test('stores a cross-midnight interval verbatim (no normalization)',
          () async {
        final id = await db.insertProfile(
          ProfilesCompanion.insert(title: const Value('Night')),
        );
        // 22:00 → 06:00 = 1320 → 360 (fromMinutes > toMinutes is legal).
        await db.into(db.intervals).insert(
              IntervalsCompanion.insert(
                profileId: id,
                fromMinutes: 1320,
                toMinutes: 360,
              ),
            );
        final list = await db.getIntervalsForProfile(id);
        expect(list, hasLength(1));
        expect(list.single.fromMinutes, 1320);
        expect(list.single.toMinutes, 360);
      });

      test('multiple intervals can be associated to the same profile',
          () async {
        final id = await db.insertProfile(
          ProfilesCompanion.insert(title: const Value('Multi')),
        );
        await db.into(db.intervals).insert(IntervalsCompanion.insert(
            profileId: id, fromMinutes: 540, toMinutes: 720));
        await db.into(db.intervals).insert(IntervalsCompanion.insert(
            profileId: id, fromMinutes: 840, toMinutes: 1080));

        final list = await db.getIntervalsForProfile(id);
        expect(list, hasLength(2));
      });
    });

    // ─── UsageLimits ───────────────────────────────────────────────────────
    group('usage limits', () {
      test('insert + getUsageLimitsForProfile', () async {
        final id = await db.insertProfile(
          ProfilesCompanion.insert(title: const Value('P')),
        );
        await db.into(db.usageLimits).insert(
              UsageLimitsCompanion.insert(
                profileId: id,
                allowedCount: const Value(30),
                originalAllowedCount: const Value(30),
                periodType: const Value(0),
                limitType: const Value(1),
              ),
            );
        final limits = await db.getUsageLimitsForProfile(id);
        expect(limits, hasLength(1));
        expect(limits.single.allowedCount, 30);
        expect(limits.single.originalAllowedCount, 30);
        expect(limits.single.usedCount, 0);
      });
    });

    // ─── Settings KV ───────────────────────────────────────────────────────
    group('settings KV', () {
      test('getSetting returns null when key is missing', () async {
        expect(await db.getSetting('nope'), isNull);
      });

      test('setSetting then getSetting roundtrip', () async {
        await db.setSetting('theme', 'dark');
        expect(await db.getSetting('theme'), 'dark');
      });

      test('setSetting overwrites a previous value (upsert)', () async {
        await db.setSetting('theme', 'dark');
        await db.setSetting('theme', 'light');
        expect(await db.getSetting('theme'), 'light');
      });

      test('different keys do not collide', () async {
        await db.setSetting('a', '1');
        await db.setSetting('b', '2');
        expect(await db.getSetting('a'), '1');
        expect(await db.getSetting('b'), '2');
      });
    });

    // ─── BlockingConfig ────────────────────────────────────────────────────
    group('blocking config', () {
      test('default row is seeded on creation', () async {
        final rows = await db.select(db.blockingConfigs).get();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'default');
        expect(rows.single.customTitle, 'Take a breath');
      });

      test('seeded default can be overwritten (insertOnConflictUpdate)',
          () async {
        await db.into(db.blockingConfigs).insertOnConflictUpdate(
              BlockingConfigsCompanion.insert(
                id: 'default',
                customTitle: const Value('Pause'),
                customColorHex: const Value('#000000'),
              ),
            );
        final row = (await db.select(db.blockingConfigs).get()).single;
        expect(row.customTitle, 'Pause');
        expect(row.customColorHex, '#000000');
      });
    });

    // ─── MoodCheckIn ──────────────────────────────────────────────────────
    group('mood check-ins', () {
      test('upsertMood + getMoodForDate roundtrip', () async {
        await db.upsertMood(
          MoodCheckInsCompanion.insert(
            mood: 4,
            day: '2026-04-17',
            createdAt: 1700,
            note: const Value('feeling good'),
            tagsJson: const Value('["calm","focused"]'),
          ),
        );

        final m = await db.getMoodForDate('2026-04-17');
        expect(m, isNotNull);
        expect(m!.mood, 4);
        expect(m.note, 'feeling good');
        expect(m.tagsJson, '["calm","focused"]');
      });

      test('upsertMood replaces an existing row for the same day', () async {
        await db.upsertMood(MoodCheckInsCompanion.insert(
          mood: 3,
          day: '2026-04-17',
          createdAt: 100,
        ));
        await db.upsertMood(MoodCheckInsCompanion.insert(
          mood: 5,
          day: '2026-04-17',
          createdAt: 200,
        ));

        final all = await db.select(db.moodCheckIns).get();
        expect(all, hasLength(1));
        expect(all.single.mood, 5);
      });

      test('getMoodForDate returns null for an unknown day', () async {
        expect(await db.getMoodForDate('2099-01-01'), isNull);
      });
    });

    // ─── BlockSessions ─────────────────────────────────────────────────────
    group('block sessions', () {
      test('insertBlockSession + getBlockSessionsInRange', () async {
        await db.insertBlockSession('Deep Work', 1000);
        await db.insertBlockSession('Mindful', 2000);
        await db.insertBlockSession('Outside', 5000);

        final inRange = await db.getBlockSessionsInRange(500, 3000);
        // timestamp < endMs is exclusive → 1000, 2000 match; 5000 doesn't.
        expect(inRange.map((s) => s.name).toSet(), {'Deep Work', 'Mindful'});
      });

      test('range with no events yields an empty list', () async {
        final list = await db.getBlockSessionsInRange(0, 1);
        expect(list, isEmpty);
      });
    });
  });
}
