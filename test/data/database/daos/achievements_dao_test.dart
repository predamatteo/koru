import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

void main() {
  group('AchievementsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    group('unlock + isUnlocked', () {
      test('isUnlocked returns false for a fresh database', () async {
        final unlocked = await db.achievementsDao.isUnlocked('focus_first');
        expect(unlocked, isFalse);
      });

      test('unlock inserts a row and isUnlocked then returns true', () async {
        await db.achievementsDao.unlock('focus_first');

        expect(await db.achievementsDao.isUnlocked('focus_first'), isTrue);
      });

      test('isUnlocked is keyed by id (no cross-contamination)', () async {
        await db.achievementsDao.unlock('focus_first');

        expect(await db.achievementsDao.isUnlocked('focus_first'), isTrue);
        expect(await db.achievementsDao.isUnlocked('monk_mode'), isFalse);
        expect(await db.achievementsDao.isUnlocked(''), isFalse);
      });

      test(
        'unlock is idempotent — calling twice does not duplicate the row',
        () async {
          await db.achievementsDao.unlock('focus_first');
          await db.achievementsDao.unlock('focus_first');
          await db.achievementsDao.unlock('focus_first');

          final all = await db.achievementsDao.getAllUnlocked();
          expect(all, hasLength(1));
          expect(all.single.id, 'focus_first');
        },
      );

      test(
        'unlock preserves the original unlockedAt on re-unlock (InsertMode.insertOrIgnore)',
        () async {
          await db.achievementsDao.unlock('focus_first');
          final original = await db.achievementsDao.getAllUnlocked();
          final originalTs = original.single.unlockedAt;

          // A noticeable wall-clock gap so the second insert WOULD have a
          // different value if it were applied.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await db.achievementsDao.unlock('focus_first');

          final after = await db.achievementsDao.getAllUnlocked();
          expect(after, hasLength(1));
          expect(after.single.unlockedAt, originalTs);
        },
      );
    });

    group('getAllUnlocked', () {
      test('returns an empty list on a fresh database', () async {
        final rows = await db.achievementsDao.getAllUnlocked();
        expect(rows, isEmpty);
      });

      test('returns every distinct unlocked id', () async {
        await db.achievementsDao.unlock('a');
        await db.achievementsDao.unlock('b');
        await db.achievementsDao.unlock('c');

        final rows = await db.achievementsDao.getAllUnlocked();
        expect(rows.length, 3);
        expect(rows.map((r) => r.id).toSet(), {'a', 'b', 'c'});
      });

      test('stores a positive unlockedAt timestamp', () async {
        final before = DateTime.now().millisecondsSinceEpoch;
        await db.achievementsDao.unlock('focus_first');
        final after = DateTime.now().millisecondsSinceEpoch;

        final row = (await db.achievementsDao.getAllUnlocked()).single;
        expect(row.unlockedAt, greaterThanOrEqualTo(before));
        expect(row.unlockedAt, lessThanOrEqualTo(after));
      });
    });

    group('watchAllUnlocked', () {
      test('initial emission is an empty list', () async {
        final stream = db.achievementsDao.watchAllUnlocked();
        await expectLater(stream, emits(isEmpty));
      });

      test('emits the new list after unlock', () async {
        final stream = db.achievementsDao.watchAllUnlocked();
        final emissions = <List<AchievementsUnlockedData>>[];
        final sub = stream.listen(emissions.add);
        // Let the initial (empty) emission land before mutating, otherwise the
        // unlock can race ahead of Drift's first query result and we never
        // observe the empty initial state.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await db.achievementsDao.unlock('focus_first');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions, isNotEmpty);
        expect(emissions.first, isEmpty);
        expect(emissions.last.map((r) => r.id), contains('focus_first'));
      });
    });
  });
}
