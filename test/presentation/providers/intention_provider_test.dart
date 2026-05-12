import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/repositories/intention_repository.dart';
import 'package:koru/presentation/providers/intention_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('intentionRecorderProvider', () {
    test('exposes an IntentionRepository bound to the db', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(intentionRecorderProvider);
      expect(repo, isA<IntentionRepository>());
    });

    test('repository.record writes a row into intention_usage_events',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(intentionRecorderProvider);
      await repo.record(
        packageName: 'com.instagram.android',
        intention: 'check_messages',
      );

      final count =
          await h.db.intentionUsageEventsDao.getLifetimeIntentionsCount();
      expect(count, 1);
    });

    test('repeated record() calls increment the count', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(intentionRecorderProvider);
      await repo.record(packageName: 'com.x', intention: 'A');
      await repo.record(packageName: 'com.x', intention: 'B');
      await repo.record(packageName: 'com.y', intention: 'A');

      final count =
          await h.db.intentionUsageEventsDao.getLifetimeIntentionsCount();
      expect(count, 3);
    });

    test('two reads return the same instance (provider caches)', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final r1 = h.container.read(intentionRecorderProvider);
      final r2 = h.container.read(intentionRecorderProvider);
      expect(identical(r1, r2), isTrue);
    });
  });
}
