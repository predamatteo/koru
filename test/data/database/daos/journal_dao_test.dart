import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

void main() {
  group('JournalDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    group('getForDay', () {
      test('returns null when there is no entry for the day', () async {
        final entry = await db.journalDao.getForDay('2026-04-17');
        expect(entry, isNull);
      });

      test('returns the entry for the day after upsert', () async {
        await db.journalDao.upsert('2026-04-17', 'today was good');

        final entry = await db.journalDao.getForDay('2026-04-17');
        expect(entry, isNotNull);
        expect(entry!.dayStartDate, '2026-04-17');
        expect(entry.body, 'today was good');
      });

      test('isolates rows by dayStartDate (no cross-day reads)', () async {
        await db.journalDao.upsert('2026-04-17', 'today');
        await db.journalDao.upsert('2026-04-18', 'tomorrow');

        final a = await db.journalDao.getForDay('2026-04-17');
        final b = await db.journalDao.getForDay('2026-04-18');
        expect(a!.body, 'today');
        expect(b!.body, 'tomorrow');
      });
    });

    group('upsert', () {
      test('first upsert sets createdAt = updatedAt = now', () async {
        final before = DateTime.now().millisecondsSinceEpoch;
        await db.journalDao.upsert('2026-04-17', 'first');
        final after = DateTime.now().millisecondsSinceEpoch;

        final entry = await db.journalDao.getForDay('2026-04-17');
        expect(entry, isNotNull);
        expect(entry!.createdAt, greaterThanOrEqualTo(before));
        expect(entry.createdAt, lessThanOrEqualTo(after));
        expect(entry.updatedAt, entry.createdAt);
      });

      test('second upsert updates body and updatedAt, preserves createdAt',
          () async {
        await db.journalDao.upsert('2026-04-17', 'first');
        final original = (await db.journalDao.getForDay('2026-04-17'))!;

        // Force a measurable wall-clock gap.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await db.journalDao.upsert('2026-04-17', 'second');

        final after = (await db.journalDao.getForDay('2026-04-17'))!;
        expect(after.body, 'second');
        expect(after.createdAt, original.createdAt);
        expect(after.updatedAt, greaterThanOrEqualTo(original.updatedAt));
      });

      test('upsert with empty body still persists', () async {
        await db.journalDao.upsert('2026-04-17', '');

        final entry = await db.journalDao.getForDay('2026-04-17');
        expect(entry, isNotNull);
        expect(entry!.body, '');
      });
    });

    group('deleteForDay', () {
      test('removes the entry for the given day', () async {
        await db.journalDao.upsert('2026-04-17', 'whatever');
        expect(await db.journalDao.getForDay('2026-04-17'), isNotNull);

        await db.journalDao.deleteForDay('2026-04-17');
        expect(await db.journalDao.getForDay('2026-04-17'), isNull);
      });

      test('is a no-op when the entry does not exist', () async {
        // Should not throw.
        await db.journalDao.deleteForDay('2099-01-01');
        expect(await db.journalDao.getForDay('2099-01-01'), isNull);
      });

      test('does not touch other days', () async {
        await db.journalDao.upsert('2026-04-17', 'keep me');
        await db.journalDao.upsert('2026-04-18', 'delete me');

        await db.journalDao.deleteForDay('2026-04-18');

        expect(await db.journalDao.getForDay('2026-04-17'), isNotNull);
        expect(await db.journalDao.getForDay('2026-04-18'), isNull);
      });
    });

    group('watchForDay', () {
      test('emits null then the inserted entry', () async {
        final stream = db.journalDao.watchForDay('2026-04-17');
        final emissions = <JournalEntry?>[];
        final sub = stream.listen(emissions.add);

        await db.journalDao.upsert('2026-04-17', 'body');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions.first, isNull);
        expect(emissions.last, isNotNull);
        expect(emissions.last!.body, 'body');
      });
    });

    group('watchAll', () {
      test('emits empty list when there are no entries', () async {
        final list = await db.journalDao.watchAll().first;
        expect(list, isEmpty);
      });

      test('orders entries by dayStartDate DESC', () async {
        await db.journalDao.upsert('2026-04-15', 'a');
        await db.journalDao.upsert('2026-04-17', 'b');
        await db.journalDao.upsert('2026-04-16', 'c');

        final list = await db.journalDao.watchAll().first;
        expect(
          list.map((e) => e.dayStartDate).toList(),
          ['2026-04-17', '2026-04-16', '2026-04-15'],
        );
      });

      test('applies the limit parameter', () async {
        for (var i = 1; i <= 5; i++) {
          await db.journalDao.upsert(
            '2026-04-${i.toString().padLeft(2, '0')}',
            'entry $i',
          );
        }

        final list = await db.journalDao.watchAll(limit: 3).first;
        expect(list, hasLength(3));
        // Newest first.
        expect(list.first.dayStartDate, '2026-04-05');
      });
    });
  });
}
