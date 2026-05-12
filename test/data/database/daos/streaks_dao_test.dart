import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

void main() {
  group('StreaksDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    group('getState', () {
      test('returns null when no row exists for the given id', () async {
        final state = await db.streaksDao.getState('focus');
        expect(state, isNull);
      });

      test('returns the row when one exists', () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(3),
            longest: const Value(7),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );
        final state = await db.streaksDao.getState('focus');
        expect(state, isNotNull);
        expect(state!.id, 'focus');
        expect(state.currentCount, 3);
        expect(state.longest, 7);
        expect(state.lastIncrementedDay, '2026-04-17');
      });

      test('isolates rows by id (different keys do not collide)', () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(5),
            longest: const Value(5),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('mindful'),
            currentCount: const Value(1),
            longest: const Value(2),
            lastIncrementedDay: const Value('2026-04-15'),
          ),
        );

        final focus = await db.streaksDao.getState('focus');
        final mindful = await db.streaksDao.getState('mindful');
        final clean = await db.streaksDao.getState('clean');

        expect(focus?.currentCount, 5);
        expect(mindful?.currentCount, 1);
        expect(clean, isNull);
      });
    });

    group('upsert', () {
      test('inserts a new row when id does not yet exist', () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(1),
            longest: const Value(1),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );

        final state = await db.streaksDao.getState('focus');
        expect(state, isNotNull);
        expect(state!.currentCount, 1);
        expect(state.longest, 1);
        expect(state.lastIncrementedDay, '2026-04-17');
      });

      test('updates currentCount on existing row (insertOnConflictUpdate)',
          () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(2),
            longest: const Value(2),
            lastIncrementedDay: const Value('2026-04-16'),
          ),
        );
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(3),
            longest: const Value(3),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );

        final state = await db.streaksDao.getState('focus');
        expect(state!.currentCount, 3);
        expect(state.longest, 3);
        expect(state.lastIncrementedDay, '2026-04-17');
      });

      test('updates longest independently of currentCount', () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(5),
            longest: const Value(5),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );
        // Reset current but keep historical longest.
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(1),
            longest: const Value(5),
            lastIncrementedDay: const Value('2026-04-20'),
          ),
        );

        final state = await db.streaksDao.getState('focus');
        expect(state!.currentCount, 1);
        expect(state.longest, 5);
      });

      test('updates lastIncrementedDay on subsequent upsert', () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(1),
            longest: const Value(1),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(2),
            longest: const Value(2),
            lastIncrementedDay: const Value('2026-04-18'),
          ),
        );

        final state = await db.streaksDao.getState('focus');
        expect(state!.lastIncrementedDay, '2026-04-18');
      });

      test('respects defaults when lastIncrementedDay is absent', () async {
        await db.streaksDao.upsert(
          const StreakStateCompanion(
            id: Value('focus'),
            currentCount: Value(0),
            longest: Value(0),
          ),
        );
        final state = await db.streaksDao.getState('focus');
        expect(state, isNotNull);
        expect(state!.currentCount, 0);
        expect(state.longest, 0);
        expect(state.lastIncrementedDay, isNull);
      });
    });

    group('watchState', () {
      test('emits null when no row exists', () async {
        final stream = db.streaksDao.watchState('focus');
        await expectLater(stream, emits(isNull));
      });

      test('emits the row after upsert', () async {
        final stream = db.streaksDao.watchState('focus');
        final emissions = <StreakStateData?>[];
        final sub = stream.listen(emissions.add);

        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(4),
            longest: const Value(10),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );
        // Wait two microtask turns for the stream to deliver.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions, isNotEmpty);
        expect(emissions.first, isNull);
        expect(emissions.last, isNotNull);
        expect(emissions.last!.currentCount, 4);
        expect(emissions.last!.longest, 10);
      });
    });

    group('watchAll', () {
      test('emits empty list when no streaks tracked', () async {
        final stream = db.streaksDao.watchAll();
        await expectLater(stream, emits(isEmpty));
      });

      test('emits all rows together (across StreakIds)', () async {
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('focus'),
            currentCount: const Value(3),
            longest: const Value(3),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );
        await db.streaksDao.upsert(
          StreakStateCompanion(
            id: const Value('mindful'),
            currentCount: const Value(2),
            longest: const Value(2),
            lastIncrementedDay: const Value('2026-04-17'),
          ),
        );

        final all = await db.streaksDao.watchAll().first;
        expect(all.length, 2);
        final ids = all.map((s) => s.id).toSet();
        expect(ids, containsAll({'focus', 'mindful'}));
      });
    });
  });
}
