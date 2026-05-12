import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/repositories/profile_repository.dart';
import 'package:koru/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('profileRepositoryProvider', () {
    test('builds a repo wired to db + native profile channel', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(profileRepositoryProvider);
      expect(repo, isA<ProfileRepository>());
    });

    test('caches the repo across reads', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final r1 = h.container.read(profileRepositoryProvider);
      final r2 = h.container.read(profileRepositoryProvider);
      expect(identical(r1, r2), isTrue);
    });
  });

  group('profilesProvider (stream)', () {
    test('emits an empty list when db has no profiles', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final list = await h.container.read(profilesProvider.stream).first;
      expect(list, isEmpty);
    });

    test('emits the inserted profile after createProfile', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // Stub channel methods (chiamati da createProfile).
      when(() => h.profileCh.notifyProfileChanged(any()))
          .thenAnswer((_) async {});

      final repo = h.container.read(profileRepositoryProvider);
      await repo.createProfile(title: 'Deep Work');

      final list = await h.container.read(profilesProvider.stream).first;
      expect(list, hasLength(1));
      expect(list.single.title, 'Deep Work');
    });

    test('emits multiple profiles in insertion order', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.profileCh.notifyProfileChanged(any()))
          .thenAnswer((_) async {});

      final repo = h.container.read(profileRepositoryProvider);
      await repo.createProfile(title: 'A');
      await repo.createProfile(title: 'B');

      final list = await h.container.read(profilesProvider.stream).first;
      expect(list.map((p) => p.title), ['A', 'B']);
    });
  });

  group('profileByIdProvider', () {
    test('returns null for an unknown id', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final model = await h.container.read(profileByIdProvider(9999).future);
      expect(model, isNull);
    });

    test('returns the profile model with the matching id', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.profileCh.notifyProfileChanged(any()))
          .thenAnswer((_) async {});

      final repo = h.container.read(profileRepositoryProvider);
      final id = await repo.createProfile(title: 'X');

      final model = await h.container.read(profileByIdProvider(id).future);
      expect(model, isNotNull);
      expect(model!.id, id);
      expect(model.title, 'X');
    });
  });
}
