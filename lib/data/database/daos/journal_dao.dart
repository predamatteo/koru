import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/journal_entries_table.dart';

part 'journal_dao.g.dart';

@DriftAccessor(tables: [JournalEntries])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  Future<JournalEntry?> getForDay(String dayKey) =>
      (select(journalEntries)..where((t) => t.dayStartDate.equals(dayKey)))
          .getSingleOrNull();

  Stream<JournalEntry?> watchForDay(String dayKey) =>
      (select(journalEntries)..where((t) => t.dayStartDate.equals(dayKey)))
          .watchSingleOrNull();

  Stream<List<JournalEntry>> watchAll({int limit = 50}) =>
      (select(journalEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.dayStartDate)])
            ..limit(limit))
          .watch();

  Future<void> upsert(String dayKey, String body) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getForDay(dayKey);
    if (existing == null) {
      await into(journalEntries).insert(
        JournalEntriesCompanion.insert(
          dayStartDate: dayKey,
          createdAt: now,
          updatedAt: now,
          body: body,
        ),
      );
    } else {
      await (update(journalEntries)
            ..where((t) => t.dayStartDate.equals(dayKey)))
          .write(
        JournalEntriesCompanion(
          updatedAt: Value(now),
          body: Value(body),
        ),
      );
    }
  }

  Future<void> deleteForDay(String dayKey) async {
    await (delete(journalEntries)..where((t) => t.dayStartDate.equals(dayKey)))
        .go();
  }
}
