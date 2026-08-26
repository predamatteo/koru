import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/streaks_repository.dart';
import 'package:koru/domain/entities/streak.dart';

void main() {
  group('StreaksRepository', () {
    late AppDatabase db;
    late StreaksRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = StreaksRepository(db.streaksDao);
    });

    tearDown(() async {
      await db.close();
    });

    // Helper: directly seed the DAO so we can simulate "what if last
    // increment was yesterday / 3 days ago / today".
    Future<void> seed(
      StreakId id, {
      required int currentCount,
      required int longest,
      required String lastIncrementedDay,
    }) =>
        db.streaksDao.upsert(
          StreakStateCompanion(
            id: Value(id.key),
            currentCount: Value(currentCount),
            longest: Value(longest),
            lastIncrementedDay: Value(lastIncrementedDay),
          ),
        );

    String dayKeyMinus(DateTime now, int days) {
      final d = DateTime(now.year, now.month, now.day - days);
      return dayKeyFor(d);
    }

    group('current', () {
      test('returns StreakSnapshot.empty when nothing is stored', () async {
        final snap = await repo.current(StreakId.mindful);
        expect(snap.id, StreakId.mindful);
        expect(snap.currentCount, 0);
        expect(snap.longest, 0);
        expect(snap.lastIncrementedDay, isNull);
      });

      test('returns the persisted values when a row exists', () async {
        await seed(
          StreakId.mindful,
          currentCount: 3,
          longest: 5,
          lastIncrementedDay: '2026-04-17',
        );
        final snap = await repo.current(StreakId.mindful);
        expect(snap.currentCount, 3);
        expect(snap.longest, 5);
        expect(snap.lastIncrementedDay, '2026-04-17');
      });
    });

    group('markToday', () {
      test('first ever mark sets current=1 and longest=1', () async {
        final snap = await repo.markToday(StreakId.mindful);
        expect(snap.currentCount, 1);
        expect(snap.longest, 1);
        expect(snap.lastIncrementedDay, dayKeyFor(DateTime.now()));
      });

      test(
          'calling markToday twice on the same calendar day is idempotent '
          '(no double-counting)', () async {
        final first = await repo.markToday(StreakId.mindful);
        final second = await repo.markToday(StreakId.mindful);
        expect(second.currentCount, first.currentCount);
        expect(second.longest, first.longest);
        expect(second.lastIncrementedDay, first.lastIncrementedDay);
      });

      test(
          'if the last increment was yesterday, current grows by 1 and '
          'longest follows when surpassed', () async {
        final now = DateTime.now();
        await seed(
          StreakId.mindful,
          currentCount: 4,
          longest: 4,
          lastIncrementedDay: dayKeyMinus(now, 1),
        );

        final snap = await repo.markToday(StreakId.mindful);
        expect(snap.currentCount, 5);
        expect(snap.longest, 5);
        expect(snap.lastIncrementedDay, dayKeyFor(now));
      });

      test(
          'when current grows but does not surpass longest, longest is kept',
          () async {
        final now = DateTime.now();
        await seed(
          StreakId.mindful,
          currentCount: 2,
          longest: 10,
          lastIncrementedDay: dayKeyMinus(now, 1),
        );

        final snap = await repo.markToday(StreakId.mindful);
        expect(snap.currentCount, 3);
        expect(snap.longest, 10);
      });

      test(
          'if there is a gap of more than one day, current resets to 1 '
          'but longest is preserved', () async {
        final now = DateTime.now();
        await seed(
          StreakId.mindful,
          currentCount: 7,
          longest: 7,
          lastIncrementedDay: dayKeyMinus(now, 3),
        );

        final snap = await repo.markToday(StreakId.mindful);
        expect(snap.currentCount, 1);
        expect(snap.longest, 7);
        expect(snap.lastIncrementedDay, dayKeyFor(now));
      });

      test('idempotent on same-day repeated calls (DB does not duplicate row)',
          () async {
        await repo.markToday(StreakId.mindful);
        await repo.markToday(StreakId.mindful);
        await repo.markToday(StreakId.mindful);

        final all = await db.streaksDao.watchAll().first;
        expect(all, hasLength(1));
        expect(all.single.currentCount, 1);
      });

      test('different StreakIds are tracked independently', () async {
        await repo.markToday(StreakId.mindful);

        final mindful = await repo.current(StreakId.mindful);
        final clean = await repo.current(StreakId.clean);
        expect(mindful.currentCount, 1);
        expect(clean.currentCount, 0); // never marked
      });
    });

    group('watch', () {
      test('emits StreakSnapshot.empty when no row exists yet', () async {
        await expectLater(
          repo.watch(StreakId.mindful),
          emits(
            isA<StreakSnapshot>()
                .having((s) => s.currentCount, 'currentCount', 0)
                .having((s) => s.longest, 'longest', 0)
                .having((s) => s.lastIncrementedDay, 'lastIncrementedDay',
                    isNull),
          ),
        );
      });

      test('emits an updated snapshot after markToday', () async {
        final emissions = <StreakSnapshot>[];
        final sub = repo.watch(StreakId.mindful).listen(emissions.add);

        await repo.markToday(StreakId.mindful);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions.first.currentCount, 0);
        expect(emissions.last.currentCount, 1);
      });
    });

    group('effectiveCurrent (static)', () {
      test('returns 0 when there is no last increment', () {
        final s = StreakSnapshot.empty(StreakId.mindful);
        expect(StreaksRepository.effectiveCurrent(s, DateTime.now()), 0);
      });

      test('returns currentCount when last increment is today', () {
        final now = DateTime(2026, 4, 17);
        final s = StreakSnapshot(
          id: StreakId.mindful,
          currentCount: 5,
          longest: 10,
          lastIncrementedDay: '2026-04-17',
        );
        expect(StreaksRepository.effectiveCurrent(s, now), 5);
      });

      test('returns currentCount when last increment is yesterday', () {
        final now = DateTime(2026, 4, 17);
        final s = StreakSnapshot(
          id: StreakId.mindful,
          currentCount: 5,
          longest: 10,
          lastIncrementedDay: '2026-04-16',
        );
        expect(StreaksRepository.effectiveCurrent(s, now), 5);
      });

      test('returns 0 when last increment is older than yesterday (lost)',
          () {
        final now = DateTime(2026, 4, 17);
        final s = StreakSnapshot(
          id: StreakId.mindful,
          currentCount: 5,
          longest: 10,
          lastIncrementedDay: '2026-04-14',
        );
        expect(StreaksRepository.effectiveCurrent(s, now), 0);
      });
    });
  });
}
