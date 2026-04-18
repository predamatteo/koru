import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../domain/entities/streak.dart';

final todayJournalProvider = StreamProvider<JournalEntry?>((ref) {
  final today = dayKeyFor(DateTime.now());
  return ref.watch(journalDaoProvider).watchForDay(today);
});

final allJournalsProvider = StreamProvider<List<JournalEntry>>((ref) {
  return ref.watch(journalDaoProvider).watchAll(limit: 100);
});

class JournalNotifier {
  JournalNotifier(this._ref);
  final Ref _ref;

  Future<void> saveToday(String body) async {
    final today = dayKeyFor(DateTime.now());
    await _ref.read(journalDaoProvider).upsert(today, body);
  }

  Future<void> deleteToday() async {
    final today = dayKeyFor(DateTime.now());
    await _ref.read(journalDaoProvider).deleteForDay(today);
  }
}

final journalNotifierProvider = Provider<JournalNotifier>(JournalNotifier.new);
