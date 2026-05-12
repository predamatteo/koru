import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/day_flags.dart';
import 'package:koru/core/constants/profile_types.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/profile_repository.dart';
import 'package:koru/platform/profile_channel.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileChannel extends Mock implements ProfileChannel {}

void main() {
  group('ProfileRepository', () {
    late AppDatabase db;
    late _MockProfileChannel channel;
    late ProfileRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      channel = _MockProfileChannel();
      // Every channel method just returns a completed future. Repo never
      // checks the return value.
      when(() => channel.notifyProfileChanged(any())).thenAnswer((_) async {});
      when(
        () => channel.notifyProfileToggled(
          profileId: any(named: 'profileId'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async {});
      repo = ProfileRepository(db: db, channel: channel);
    });

    tearDown(() async {
      await db.close();
    });

    group('createProfile', () {
      test('returns a valid id and persists the row with custom fields',
          () async {
        final id = await repo.createProfile(
          title: 'Deep Work',
          emoji: '🎯',
          blockingMode: BlockingMode.allowlist,
          dayFlags: DayFlags.weekdays,
          typeCombinations: ProfileType.time,
          colorHex: '#8A6D52',
          presetId: 99,
        );

        expect(id, greaterThan(0));
        final row = await db.getProfileById(id);
        expect(row, isNotNull);
        expect(row!.title, 'Deep Work');
        expect(row.emoji, '🎯');
        expect(row.blockingMode, BlockingMode.allowlist);
        expect(row.dayFlags, DayFlags.weekdays);
        expect(row.typeCombinations, ProfileType.time);
        expect(row.colorHex, '#8A6D52');
        expect(row.presetId, 99);
      });

      test('applies defaults when only a title is passed', () async {
        final id = await repo.createProfile(title: 'Plain');
        final row = await db.getProfileById(id);
        expect(row!.emoji, 'NoIcon');
        expect(row.blockingMode, 0);
        expect(row.dayFlags, 127);
        expect(row.typeCombinations, 1);
        expect(row.colorHex, '#5C8262');
        expect(row.presetId, isNull);
      });

      test('notifies the native channel after creating', () async {
        final id = await repo.createProfile(title: 'P');
        verify(() => channel.notifyProfileChanged(id)).called(1);
      });
    });

    group('getProfileWithRelations', () {
      test('returns null when the id does not exist', () async {
        expect(await repo.getProfileWithRelations(9999), isNull);
      });

      test(
          'returns a ProfileModel with all related rows loaded '
          '(apps/websites/intervals/usageLimits)', () async {
        final id = await repo.createProfile(
          title: 'Full',
          typeCombinations: ProfileType.time | ProfileType.usageLimit,
        );
        await db.setAppsForProfile(id, ['com.a', 'com.b']);
        await db.into(db.websiteRules).insert(
              WebsiteRulesCompanion.insert(
                profileId: id,
                name: 'reddit.com',
              ),
            );
        await db.into(db.intervals).insert(
              IntervalsCompanion.insert(
                profileId: id,
                fromMinutes: 540,
                toMinutes: 1020,
              ),
            );
        await db.into(db.usageLimits).insert(
              UsageLimitsCompanion.insert(
                profileId: id,
                allowedCount: const Value(30),
                originalAllowedCount: const Value(30),
              ),
            );

        final model = await repo.getProfileWithRelations(id);
        expect(model, isNotNull);
        expect(model!.id, id);
        expect(model.apps.map((r) => r.packageName).toSet(),
            {'com.a', 'com.b'});
        expect(model.websites, hasLength(1));
        expect(model.intervals, hasLength(1));
        expect(model.usageLimits, hasLength(1));
      });
    });

    group('toggleProfile', () {
      test('flips isEnabled and notifies the channel', () async {
        final id = await repo.createProfile(title: 'P');
        expect((await db.getProfileById(id))!.isEnabled, isFalse);

        await repo.toggleProfile(id, true);
        expect((await db.getProfileById(id))!.isEnabled, isTrue);

        verify(
          () => channel.notifyProfileToggled(profileId: id, enabled: true),
        ).called(1);

        await repo.toggleProfile(id, false);
        expect((await db.getProfileById(id))!.isEnabled, isFalse);
        verify(
          () => channel.notifyProfileToggled(profileId: id, enabled: false),
        ).called(1);
      });

      test('no-op on a missing id (does not throw, does not notify)',
          () async {
        await repo.toggleProfile(99999, true);
        verifyNever(
          () => channel.notifyProfileToggled(
            profileId: any(named: 'profileId'),
            enabled: any(named: 'enabled'),
          ),
        );
      });
    });

    group('deleteProfile', () {
      test('removes the row and notifies the channel', () async {
        final id = await repo.createProfile(title: 'P');
        // Reset captures so we only verify the post-delete notification.
        clearInteractions(channel);

        await repo.deleteProfile(id);
        expect(await db.getProfileById(id), isNull);
        verify(() => channel.notifyProfileChanged(id)).called(1);
      });
    });

    group('updateProfileDetails', () {
      test('only modifies the explicitly passed fields', () async {
        final id = await repo.createProfile(
          title: 'Old',
          emoji: 'old_emoji',
          colorHex: '#111111',
        );
        await repo.updateProfileDetails(
          id: id,
          title: 'New',
          colorHex: '#222222',
        );

        final row = await db.getProfileById(id);
        expect(row!.title, 'New');
        expect(row.colorHex, '#222222');
        // Untouched.
        expect(row.emoji, 'old_emoji');
      });

      test('no-op on a missing id', () async {
        // Just verify no throw and no notify.
        clearInteractions(channel);
        await repo.updateProfileDetails(id: 9999, title: 'X');
        verifyNever(() => channel.notifyProfileChanged(any()));
      });
    });

    group('setAppsForProfile', () {
      test('adds new package relations', () async {
        final id = await repo.createProfile(title: 'P');
        await repo.setAppsForProfile(id, ['com.a', 'com.b']);

        final rels = await db.getAppsForProfile(id);
        expect(rels.map((r) => r.packageName).toSet(), {'com.a', 'com.b'});
      });

      test('removes packages no longer in the list', () async {
        final id = await repo.createProfile(title: 'P');
        await repo.setAppsForProfile(id, ['com.a', 'com.b']);
        await repo.setAppsForProfile(id, ['com.a']);

        final rels = await db.getAppsForProfile(id);
        expect(rels.map((r) => r.packageName), ['com.a']);
      });

      test(
          'auto-populates blockedSectionsJson for supported packages on first add',
          () async {
        final id = await repo.createProfile(title: 'P');
        await repo.setAppsForProfile(id, ['com.instagram.android']);

        final rel = (await db.getAppsForProfile(id)).single;
        expect(rel.blockedSectionsJson, isNotNull);
        // The serialized form is JSON with a "sections" array — sanity-check
        // we got something looking like that.
        expect(rel.blockedSectionsJson, contains('sections'));
      });

      test('notifies the channel after the change', () async {
        final id = await repo.createProfile(title: 'P');
        clearInteractions(channel);

        await repo.setAppsForProfile(id, ['com.a']);
        verify(() => channel.notifyProfileChanged(id)).called(1);
      });
    });

    group('intervals (set + read)', () {
      test('setIntervalsForProfile replaces all existing intervals', () async {
        final id = await repo.createProfile(title: 'P');
        await repo.setIntervalsForProfile(id, [
          (from: 540, to: 720),
          (from: 840, to: 1020),
        ]);
        var rows = await db.getIntervalsForProfile(id);
        expect(rows, hasLength(2));

        // Replace with a single, different interval.
        await repo.setIntervalsForProfile(id, [(from: 1320, to: 360)]);
        rows = await db.getIntervalsForProfile(id);
        expect(rows, hasLength(1));
        expect(rows.single.fromMinutes, 1320);
        expect(rows.single.toMinutes, 360);
      });

      test('setIntervalsForProfile with empty list deletes all intervals',
          () async {
        final id = await repo.createProfile(title: 'P');
        await repo.setIntervalsForProfile(id, [(from: 540, to: 720)]);
        await repo.setIntervalsForProfile(id, const []);
        expect(await db.getIntervalsForProfile(id), isEmpty);
      });
    });

    group('website rules', () {
      test('addWebsiteRule then deleteWebsiteRule roundtrip', () async {
        final id = await repo.createProfile(title: 'P');
        await repo.addWebsiteRule(
          profileId: id,
          name: 'reddit.com',
          isAnywhereInUrl: true,
        );
        var rules = await db.getWebsiteRulesForProfile(id);
        expect(rules, hasLength(1));
        expect(rules.single.name, 'reddit.com');
        expect(rules.single.isAnywhereInUrl, isTrue);

        await repo.deleteWebsiteRule(rules.single.id, id);
        rules = await db.getWebsiteRulesForProfile(id);
        expect(rules, isEmpty);
      });

      test('addWebsiteRule notifies the channel', () async {
        final id = await repo.createProfile(title: 'P');
        clearInteractions(channel);
        await repo.addWebsiteRule(profileId: id, name: 'a.com');
        verify(() => channel.notifyProfileChanged(id)).called(1);
      });
    });

    group('wifi networks', () {
      test('getWifisForProfile returns empty list initially', () async {
        final id = await repo.createProfile(title: 'P');
        expect(await repo.getWifisForProfile(id), isEmpty);
      });

      test('setWifisForProfile replaces all SSIDs and trims whitespace',
          () async {
        final id = await repo.createProfile(title: 'P');
        await repo.setWifisForProfile(id, ['Home WiFi', '  Office  ', '']);

        final ssids = await repo.getWifisForProfile(id);
        // Empty string ignored, the rest trimmed.
        expect(ssids, containsAll(['Home WiFi', 'Office']));
        expect(ssids.length, 2);
      });
    });

    group('watchAllProfiles', () {
      test('emits the current set of ProfileModels', () async {
        await repo.createProfile(title: 'A');
        await repo.createProfile(title: 'B');

        final models = await repo.watchAllProfiles().first;
        expect(models, hasLength(2));
        expect(models.map((m) => m.title).toSet(), {'A', 'B'});
      });
    });
  });
}
