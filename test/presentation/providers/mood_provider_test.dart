import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/repositories/mood_repository.dart';
import 'package:koru/presentation/providers/mood_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('moodRepositoryProvider', () {
    test('builds a MoodRepository wired to the db', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(moodRepositoryProvider);
      expect(repo, isA<MoodRepository>());
    });

    test('two reads of the provider return the same instance', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo1 = h.container.read(moodRepositoryProvider);
      final repo2 = h.container.read(moodRepositoryProvider);
      expect(identical(repo1, repo2), isTrue);
    });
  });

  group('todayMoodProvider', () {
    test('returns null on empty db', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final mood = await h.container.read(todayMoodProvider.future);
      expect(mood, isNull);
    });

    test('returns the stored mood after upsert (today)', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(moodRepositoryProvider);
      await repo.upsertToday(mood: 4, note: 'pretty good');

      // Invalidate per ri-fetchare il provider dopo l'insert.
      h.container.invalidate(todayMoodProvider);
      final mood = await h.container.read(todayMoodProvider.future);
      expect(mood, isNotNull);
      expect(mood!.mood, 4);
      expect(mood.note, 'pretty good');
    });
  });
}
