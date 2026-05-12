import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/intention_repository.dart';

void main() {
  group('IntentionRepository', () {
    late AppDatabase db;
    late IntentionRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = IntentionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('record stores a row with occurredAt near now', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await repo.record(
        packageName: 'com.instagram.android',
        intention: 'Check messages',
      );
      final after = DateTime.now().millisecondsSinceEpoch;

      final row = (await db.select(db.intentionUsageEvents).get()).single;
      expect(row.packageName, 'com.instagram.android');
      expect(row.intentionName, 'Check messages');
      expect(row.occurredAt, greaterThanOrEqualTo(before));
      expect(row.occurredAt, lessThanOrEqualTo(after));
    });

    test('record uses today\'s YYYY-MM-DD as dayStartDate', () async {
      final today = DateTime.now();
      final expected = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await repo.record(packageName: 'com.x', intention: 'check feed');
      final row = (await db.select(db.intentionUsageEvents).get()).single;
      expect(row.dayStartDate, expected);
    });

    test(
        'multiple records on the same package + same intention each create '
        'a new row (count totals)', () async {
      await repo.record(packageName: 'com.x', intention: 'check feed');
      await repo.record(packageName: 'com.x', intention: 'check feed');
      await repo.record(packageName: 'com.x', intention: 'check feed');

      final count = await db.intentionUsageEventsDao
          .getLifetimeIntentionsCount();
      expect(count, 3);
    });

    test('records for different packages do not collide', () async {
      await repo.record(packageName: 'com.x', intention: 'check feed');
      await repo.record(packageName: 'com.y', intention: 'check feed');

      final rows = await db.select(db.intentionUsageEvents).get();
      expect(rows.map((r) => r.packageName).toSet(), {'com.x', 'com.y'});
    });

    test('per-intention aggregate via DAO groups our recorded events',
        () async {
      await repo.record(packageName: 'com.x', intention: 'check feed');
      await repo.record(packageName: 'com.x', intention: 'check feed');
      await repo.record(packageName: 'com.x', intention: 'post a story');

      final today = DateTime.now();
      final day = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final results = await db.intentionUsageEventsDao
          .watchIntentionsUsages(day, day)
          .first;
      final byTitle = {for (final r in results) r.title: r.usageCount};
      expect(byTitle['check feed'], 2);
      expect(byTitle['post a story'], 1);
    });
  });
}
