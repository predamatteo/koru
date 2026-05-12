import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/streak.dart';
import 'package:koru/presentation/providers/journal_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('todayJournalProvider (stream)', () {
    test('emits null when no entry exists for today', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final entry = await h.container.read(todayJournalProvider.stream).first;
      expect(entry, isNull);
    });

    test('emits the saved entry after upsert for today', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = dayKeyFor(DateTime.now());
      await h.db.journalDao.upsert(today, 'first entry');

      final entry = await h.container.read(todayJournalProvider.stream).first;
      expect(entry, isNotNull);
      expect(entry!.body, 'first entry');
      expect(entry.dayStartDate, today);
    });
  });

  group('allJournalsProvider (stream)', () {
    test('emits empty list on a clean db', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final list = await h.container.read(allJournalsProvider.stream).first;
      expect(list, isEmpty);
    });

    test('emits multiple entries ordered desc by dayStartDate', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.journalDao.upsert('2026-04-10', 'old');
      await h.db.journalDao.upsert('2026-05-10', 'new');

      final list = await h.container.read(allJournalsProvider.stream).first;
      expect(list, hasLength(2));
      expect(list.first.dayStartDate, '2026-05-10');
      expect(list.last.dayStartDate, '2026-04-10');
    });
  });

  group('JournalNotifier', () {
    test('saveToday persists a journal entry for today', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final notifier = h.container.read(journalNotifierProvider);
      await notifier.saveToday('hello journal');

      final today = dayKeyFor(DateTime.now());
      final entry = await h.db.journalDao.getForDay(today);
      expect(entry, isNotNull);
      expect(entry!.body, 'hello journal');
    });

    test('deleteToday removes the entry for today', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = dayKeyFor(DateTime.now());
      await h.db.journalDao.upsert(today, 'tmp');

      final notifier = h.container.read(journalNotifierProvider);
      await notifier.deleteToday();

      final entry = await h.db.journalDao.getForDay(today);
      expect(entry, isNull);
    });
  });
}
