import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/database/daos/intention_usage_events_dao.dart';

void main() {
  group('IntentionUsageEventsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insert({
      required String packageName,
      required String intention,
      required String day,
    }) =>
        db.intentionUsageEventsDao.insertEvent(
          IntentionUsageEventsCompanion.insert(
            occurredAt: DateTime.now().millisecondsSinceEpoch,
            dayStartDate: day,
            packageName: packageName,
            intentionName: intention,
          ),
        );

    group('insertEvent', () {
      test('inserts a row that survives a re-select', () async {
        await insert(
          packageName: 'com.instagram.android',
          intention: 'Check messages',
          day: '2026-04-17',
        );

        final rows = await db.select(db.intentionUsageEvents).get();
        expect(rows, hasLength(1));
        expect(rows.single.packageName, 'com.instagram.android');
        expect(rows.single.intentionName, 'Check messages');
        expect(rows.single.dayStartDate, '2026-04-17');
      });

      test('does not collapse different intentions on the same package',
          () async {
        await insert(
          packageName: 'com.instagram.android',
          intention: 'Check messages',
          day: '2026-04-17',
        );
        await insert(
          packageName: 'com.instagram.android',
          intention: 'Post a story',
          day: '2026-04-17',
        );

        final rows = await db.select(db.intentionUsageEvents).get();
        expect(rows, hasLength(2));
      });
    });

    group('getLifetimeIntentionsCount', () {
      test('returns 0 when no events are tracked', () async {
        expect(
          await db.intentionUsageEventsDao.getLifetimeIntentionsCount(),
          0,
        );
      });

      test('counts every recorded event (one per insert)', () async {
        await insert(
          packageName: 'com.instagram.android',
          intention: 'a',
          day: '2026-04-17',
        );
        await insert(
          packageName: 'com.instagram.android',
          intention: 'b',
          day: '2026-04-17',
        );
        await insert(
          packageName: 'com.tiktok.android',
          intention: 'c',
          day: '2026-04-18',
        );

        expect(
          await db.intentionUsageEventsDao.getLifetimeIntentionsCount(),
          3,
        );
      });
    });

    group('watchIntentionsUsages (per-intention aggregate)', () {
      test('emits an empty list when no events match the range', () async {
        final stream = db.intentionUsageEventsDao
            .watchIntentionsUsages('2026-04-17', '2026-04-17');
        await expectLater(stream, emits(isEmpty));
      });

      test('groups by intention_name and counts within range', () async {
        await insert(
          packageName: 'com.instagram.android',
          intention: 'Check messages',
          day: '2026-04-17',
        );
        await insert(
          packageName: 'com.tiktok.android',
          intention: 'Check messages',
          day: '2026-04-17',
        );
        await insert(
          packageName: 'com.instagram.android',
          intention: 'Post a story',
          day: '2026-04-17',
        );
        // Outside range — must be excluded.
        await insert(
          packageName: 'com.instagram.android',
          intention: 'Check messages',
          day: '2026-04-19',
        );

        final results = await db.intentionUsageEventsDao
            .watchIntentionsUsages('2026-04-17', '2026-04-17')
            .first;

        expect(results, hasLength(2));
        final byTitle = {for (final r in results) r.title: r.usageCount};
        expect(byTitle['Check messages'], 2);
        expect(byTitle['Post a story'], 1);
      });

      test('orders results by usage_count DESC', () async {
        await insert(
          packageName: 'com.instagram.android',
          intention: 'low',
          day: '2026-04-17',
        );
        for (var i = 0; i < 3; i++) {
          await insert(
            packageName: 'com.instagram.android',
            intention: 'high',
            day: '2026-04-17',
          );
        }

        final results = await db.intentionUsageEventsDao
            .watchIntentionsUsages('2026-04-17', '2026-04-17')
            .first;
        expect(results.first.title, 'high');
        expect(results.first.usageCount, 3);
        expect(results.last.title, 'low');
        expect(results.last.usageCount, 1);
      });

      test('respects BETWEEN inclusivity for the day range', () async {
        await insert(
          packageName: 'com.instagram.android',
          intention: 'a',
          day: '2026-04-16',
        );
        await insert(
          packageName: 'com.instagram.android',
          intention: 'a',
          day: '2026-04-17',
        );
        await insert(
          packageName: 'com.instagram.android',
          intention: 'a',
          day: '2026-04-18',
        );

        final results = await db.intentionUsageEventsDao
            .watchIntentionsUsages('2026-04-17', '2026-04-18')
            .first;
        expect(results, hasLength(1));
        expect(results.single.title, 'a');
        expect(results.single.usageCount, 2);
      });
    });

    test('IntentionUsageResult is a plain data holder', () {
      final r = IntentionUsageResult(title: 'foo', usageCount: 7);
      expect(r.title, 'foo');
      expect(r.usageCount, 7);
    });
  });
}
