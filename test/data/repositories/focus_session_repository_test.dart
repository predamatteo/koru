import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/focus_session_repository.dart';

void main() {
  group('FocusSessionRepository', () {
    late AppDatabase db;
    late FocusSessionRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = FocusSessionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('recordCompletedSession persists a row with the duration in ms',
        () async {
      await repo.recordCompletedSession(const Duration(minutes: 25));

      final rows = await db.select(db.focusUsageEvents).get();
      expect(rows, hasLength(1));
      expect(rows.single.durationInMs, 25 * 60 * 1000);
    });

    test('recordCompletedSession uses today\'s YYYY-MM-DD day-key', () async {
      final today = DateTime.now();
      final expectedDay = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await repo.recordCompletedSession(const Duration(minutes: 5));
      final rows = await db.select(db.focusUsageEvents).get();
      expect(rows.single.dayStartDate, expectedDay);
    });

    test('multiple recordCompletedSession calls aggregate via lifetime stat',
        () async {
      await repo.recordCompletedSession(const Duration(minutes: 25));
      await repo.recordCompletedSession(const Duration(minutes: 5));
      await repo.recordCompletedSession(const Duration(minutes: 50));

      final lifetime = await db.focusUsageEventsDao.getLifetimeFocusMs();
      expect(lifetime, (25 + 5 + 50) * 60 * 1000);
    });

    test('zero-duration session is still recorded', () async {
      await repo.recordCompletedSession(Duration.zero);

      final rows = await db.select(db.focusUsageEvents).get();
      expect(rows, hasLength(1));
      expect(rows.single.durationInMs, 0);
    });

    test('occurredAt is a positive timestamp near now', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await repo.recordCompletedSession(const Duration(minutes: 1));
      final after = DateTime.now().millisecondsSinceEpoch;

      final row = (await db.select(db.focusUsageEvents).get()).single;
      expect(row.occurredAt, greaterThanOrEqualTo(before));
      expect(row.occurredAt, lessThanOrEqualTo(after));
    });
  });
}
