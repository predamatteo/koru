import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

void main() {
  group('FocusUsageEventsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insert({
      required String day,
      required int durationMs,
      int? occurredAt,
    }) => db.focusUsageEventsDao.insertEvent(
      FocusUsageEventsCompanion.insert(
        occurredAt: occurredAt ?? DateTime.now().millisecondsSinceEpoch,
        dayStartDate: day,
        durationInMs: durationMs,
      ),
    );

    group('insertEvent', () {
      test('inserts a row that survives a re-select', () async {
        await insert(day: '2026-04-17', durationMs: 1500);

        final rows = await db.select(db.focusUsageEvents).get();
        expect(rows, hasLength(1));
        expect(rows.single.dayStartDate, '2026-04-17');
        expect(rows.single.durationInMs, 1500);
      });

      test('autoIncrements id on each insert', () async {
        await insert(day: '2026-04-17', durationMs: 100);
        await insert(day: '2026-04-17', durationMs: 200);
        await insert(day: '2026-04-17', durationMs: 300);

        final ids = (await db.select(db.focusUsageEvents).get())
            .map((e) => e.id)
            .toSet();
        expect(ids.length, 3);
      });
    });

    group('getLifetimeFocusMs', () {
      test('returns 0 when no events are tracked', () async {
        expect(await db.focusUsageEventsDao.getLifetimeFocusMs(), 0);
      });

      test('sums durations across every recorded event', () async {
        await insert(day: '2026-04-17', durationMs: 1000);
        await insert(day: '2026-04-17', durationMs: 2000);
        await insert(day: '2026-04-18', durationMs: 3500);

        expect(await db.focusUsageEventsDao.getLifetimeFocusMs(), 6500);
      });
    });

    group('watchFocusTimeUsage (range filter)', () {
      test('emits 0 when no events fall in range', () async {
        final stream = db.focusUsageEventsDao.watchFocusTimeUsage(
          '2026-04-17',
          '2026-04-17',
        );
        await expectLater(stream, emits(0));
      });

      test(
        'sums only events whose dayStartDate is within [from, to]',
        () async {
          await insert(day: '2026-04-15', durationMs: 100);
          await insert(day: '2026-04-16', durationMs: 200);
          await insert(day: '2026-04-17', durationMs: 400);
          await insert(day: '2026-04-18', durationMs: 800);

          final sum = await db.focusUsageEventsDao
              .watchFocusTimeUsage('2026-04-16', '2026-04-17')
              .first;
          expect(sum, 600);
        },
      );

      test('BETWEEN bounds are inclusive', () async {
        await insert(day: '2026-04-17', durationMs: 1000);
        await insert(day: '2026-04-19', durationMs: 1000);

        // Range that includes both end dates.
        final inclusive = await db.focusUsageEventsDao
            .watchFocusTimeUsage('2026-04-17', '2026-04-19')
            .first;
        expect(inclusive, 2000);
      });

      test('exclusive range yields 0 (from > to)', () async {
        await insert(day: '2026-04-17', durationMs: 1000);

        // YYYY-MM-DD ordering: 2026-04-20 > 2026-04-19, so SQLite BETWEEN
        // with from > to never matches.
        final sum = await db.focusUsageEventsDao
            .watchFocusTimeUsage('2026-04-20', '2026-04-19')
            .first;
        expect(sum, 0);
      });

      test('stream re-emits after a new event is inserted', () async {
        final stream = db.focusUsageEventsDao.watchFocusTimeUsage(
          '2026-04-17',
          '2026-04-17',
        );
        final emissions = <int>[];
        final sub = stream.listen(emissions.add);
        // Let the initial (0) emission land before mutating, otherwise the
        // insert can race ahead of Drift's first query result and we never
        // observe the empty initial state.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await insert(day: '2026-04-17', durationMs: 1500);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions.first, 0);
        expect(emissions.last, 1500);
      });
    });
  });
}
