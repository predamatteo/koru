import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/mood_repository.dart';

void main() {
  group('MoodRepository', () {
    late AppDatabase db;
    late MoodRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = MoodRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    String todayKey() {
      final d = DateTime.now();
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    group('getForToday', () {
      test('returns null when there is no check-in for today', () async {
        expect(await repo.getForToday(), isNull);
      });

      test('returns the row once upsertToday has been called', () async {
        await repo.upsertToday(mood: 4);
        final m = await repo.getForToday();
        expect(m, isNotNull);
        expect(m!.mood, 4);
        expect(m.day, todayKey());
      });
    });

    group('upsertToday', () {
      test('inserts a new row with the given mood + null note/tagsJson by default',
          () async {
        await repo.upsertToday(mood: 5);
        final m = await repo.getForToday();
        expect(m!.mood, 5);
        expect(m.note, isNull);
        expect(m.tagsJson, isNull);
      });

      test('persists note and tagsJson when provided', () async {
        await repo.upsertToday(
          mood: 3,
          note: 'meh',
          tagsJson: '["tired","cloudy"]',
        );
        final m = await repo.getForToday();
        expect(m!.mood, 3);
        expect(m.note, 'meh');
        expect(m.tagsJson, '["tired","cloudy"]');
      });

      test('second call for the same day replaces the previous row', () async {
        await repo.upsertToday(mood: 2);
        await repo.upsertToday(mood: 5, note: 'changed my mind');

        final allRows = await db.select(db.moodCheckIns).get();
        expect(allRows, hasLength(1));
        expect(allRows.single.mood, 5);
        expect(allRows.single.note, 'changed my mind');
      });

      test('createdAt is a positive timestamp set near now', () async {
        final before = DateTime.now().millisecondsSinceEpoch;
        await repo.upsertToday(mood: 4);
        final after = DateTime.now().millisecondsSinceEpoch;

        final m = await repo.getForToday();
        expect(m!.createdAt, greaterThanOrEqualTo(before));
        expect(m.createdAt, lessThanOrEqualTo(after));
      });
    });

    test(
        'getForToday + a row inserted directly for another day do not collide',
        () async {
      // Use the underlying DB to plant a row for a known-past day.
      await db.upsertMood(
        MoodCheckInsCompanion.insert(
          mood: 1,
          day: '2000-01-01',
          createdAt: 0,
        ),
      );
      expect(await repo.getForToday(), isNull);

      // And the past row is still queryable via the raw DAO method.
      final past = await db.getMoodForDate('2000-01-01');
      expect(past, isNotNull);
      expect(past!.mood, 1);
    });
  });
}
