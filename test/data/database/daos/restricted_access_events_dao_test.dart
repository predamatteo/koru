import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/database/daos/restricted_access_events_dao.dart';

void main() {
  group('RestrictedAccessEventsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    // Event types (from table comment): 0=BLOCK_TRIGGERED, 1=BLOCK_SKIPPED.
    // Restriction types: 0=APP, 1=SECTION, 2=WEBSITE, 3=USAGE_LIMIT, 4=FOCUS_MODE.
    Future<void> insert({
      required String day,
      required String pkg,
      required int eventType,
      required int restrictionType,
    }) =>
        db.restrictedAccessEventsDao.insertEvent(
          RestrictedAccessEventsCompanion.insert(
            occurredAt: DateTime.now().millisecondsSinceEpoch,
            dayStartDate: day,
            packageName: pkg,
            eventType: eventType,
            restrictionType: restrictionType,
          ),
        );

    group('insertEvent', () {
      test('persists a row that can be re-selected', () async {
        await insert(
          day: '2026-04-17',
          pkg: 'com.instagram.android',
          eventType: 0,
          restrictionType: 0,
        );

        final rows = await db.select(db.restrictedAccessEvents).get();
        expect(rows, hasLength(1));
        expect(rows.single.packageName, 'com.instagram.android');
        expect(rows.single.eventType, 0);
        expect(rows.single.restrictionType, 0);
      });
    });

    group('countEventsByTypeInRange', () {
      test('returns 0 when no events match', () async {
        final count = await db.restrictedAccessEventsDao
            .countEventsByTypeInRange(0, '2026-04-17', '2026-04-17');
        expect(count, 0);
      });

      test('counts only events with the given eventType', () async {
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 1,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );

        final triggered = await db.restrictedAccessEventsDao
            .countEventsByTypeInRange(0, '2026-04-17', '2026-04-17');
        final skipped = await db.restrictedAccessEventsDao
            .countEventsByTypeInRange(1, '2026-04-17', '2026-04-17');
        expect(triggered, 2);
        expect(skipped, 1);
      });

      test('excludes events outside the [from, to] range', () async {
        await insert(
          day: '2026-04-16',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-18',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );

        final count = await db.restrictedAccessEventsDao
            .countEventsByTypeInRange(0, '2026-04-17', '2026-04-17');
        expect(count, 1);
      });

      test('BETWEEN bounds are inclusive on both ends', () async {
        await insert(
          day: '2026-04-15',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );

        final count = await db.restrictedAccessEventsDao
            .countEventsByTypeInRange(0, '2026-04-15', '2026-04-17');
        expect(count, 2);
      });

      test('returns 0 when the range does not intersect any event', () async {
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );

        final count = await db.restrictedAccessEventsDao
            .countEventsByTypeInRange(0, '2025-01-01', '2025-01-31');
        expect(count, 0);
      });
    });

    group('getLifetimeHonestBlockCount', () {
      test('returns 0 on a fresh database', () async {
        expect(
          await db.restrictedAccessEventsDao.getLifetimeHonestBlockCount(),
          0,
        );
      });

      test('only counts eventType=0 (BLOCK_TRIGGERED) across all days',
          () async {
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 1, // skipped, must NOT be counted
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-18',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-19',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );

        expect(
          await db.restrictedAccessEventsDao.getLifetimeHonestBlockCount(),
          3,
        );
      });
    });

    group('watchCountEventsByTypeInRange', () {
      test('emits 0 then re-emits after a matching insert', () async {
        final stream = db.restrictedAccessEventsDao
            .watchCountEventsByTypeInRange(0, '2026-04-17', '2026-04-17');
        final emissions = <int>[];
        final sub = stream.listen(emissions.add);

        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions.first, 0);
        expect(emissions.last, 1);
      });
    });

    group('watchCountByRestrictionTypeInRange', () {
      test('counts only events with the given restrictionType', () async {
        // 0=APP, 1=SECTION, 2=WEBSITE.
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 1,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 1,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 2,
        );

        final app = await db.restrictedAccessEventsDao
            .watchCountByRestrictionTypeInRange(0, '2026-04-17', '2026-04-17')
            .first;
        final section = await db.restrictedAccessEventsDao
            .watchCountByRestrictionTypeInRange(1, '2026-04-17', '2026-04-17')
            .first;
        final website = await db.restrictedAccessEventsDao
            .watchCountByRestrictionTypeInRange(2, '2026-04-17', '2026-04-17')
            .first;
        final focus = await db.restrictedAccessEventsDao
            .watchCountByRestrictionTypeInRange(4, '2026-04-17', '2026-04-17')
            .first;

        expect(app, 1);
        expect(section, 2);
        expect(website, 1);
        expect(focus, 0);
      });

      test('excludes events outside the range', () async {
        await insert(
          day: '2026-04-15',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );

        final count = await db.restrictedAccessEventsDao
            .watchCountByRestrictionTypeInRange(
              0,
              '2026-04-17',
              '2026-04-17',
            )
            .first;
        expect(count, 1);
      });
    });

    group('watchPerAppBreakdown', () {
      test('emits empty list when no events match', () async {
        final stream = db.restrictedAccessEventsDao
            .watchPerAppBreakdown('2026-04-17', '2026-04-17');
        await expectLater(stream, emits(isEmpty));
      });

      test('groups by (package_name, event_type) and orders by count DESC',
          () async {
        // 4 BLOCK_TRIGGERED on instagram
        for (var i = 0; i < 4; i++) {
          await insert(
            day: '2026-04-17',
            pkg: 'com.instagram.android',
            eventType: 0,
            restrictionType: 0,
          );
        }
        // 2 BLOCK_SKIPPED on instagram → separate group
        for (var i = 0; i < 2; i++) {
          await insert(
            day: '2026-04-17',
            pkg: 'com.instagram.android',
            eventType: 1,
            restrictionType: 0,
          );
        }
        // 1 BLOCK_TRIGGERED on tiktok
        await insert(
          day: '2026-04-17',
          pkg: 'com.tiktok.android',
          eventType: 0,
          restrictionType: 0,
        );

        final stats = await db.restrictedAccessEventsDao
            .watchPerAppBreakdown('2026-04-17', '2026-04-17')
            .first;

        expect(stats, hasLength(3));
        // First row is the largest group.
        expect(stats.first.packageName, 'com.instagram.android');
        expect(stats.first.eventType, 0);
        expect(stats.first.count, 4);
        // counts strictly non-increasing
        for (var i = 1; i < stats.length; i++) {
          expect(stats[i].count, lessThanOrEqualTo(stats[i - 1].count));
        }
      });

      test('filters by the day range', () async {
        await insert(
          day: '2026-04-15',
          pkg: 'com.x',
          eventType: 0,
          restrictionType: 0,
        );
        await insert(
          day: '2026-04-17',
          pkg: 'com.y',
          eventType: 0,
          restrictionType: 0,
        );

        final stats = await db.restrictedAccessEventsDao
            .watchPerAppBreakdown('2026-04-17', '2026-04-17')
            .first;
        expect(stats, hasLength(1));
        expect(stats.single.packageName, 'com.y');
      });
    });

    test('PerAppStatResult is a plain data holder', () {
      final r = PerAppStatResult(
        packageName: 'com.x',
        count: 5,
        eventType: 0,
      );
      expect(r.packageName, 'com.x');
      expect(r.count, 5);
      expect(r.eventType, 0);
    });
  });
}
