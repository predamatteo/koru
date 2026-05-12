import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/providers/favorites_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('favoritesProvider (stream)', () {
    test('emits empty list when db has no favorites', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final first = await h.container.read(favoritesProvider.stream).first;
      expect(first, isEmpty);
    });

    test('emits package names in orderIndex ascending order', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.db.addFavorite('com.b', label: 'Beta');
      await h.db.addFavorite('com.c', label: 'Charlie');

      final list = await h.container.read(favoritesProvider.stream).first;
      expect(list, ['com.a', 'com.b', 'com.c']);
    });
  });

  group('favoriteAppsProvider', () {
    test('resolves favorites against installedAppsProvider preserving order',
        () async {
      // Override installedAppsProvider con un valore noto e statico.
      final installed = [
        InstalledAppInfo(packageName: 'com.b', label: 'Beta'),
        InstalledAppInfo(packageName: 'com.a', label: 'Alpha'),
        InstalledAppInfo(packageName: 'com.c', label: 'Charlie'),
      ];
      final h = buildTestContainer(extra: [
        installedAppsProvider.overrideWith((ref) async => installed),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.db.addFavorite('com.c', label: 'Charlie');

      // Drena lo stream (force resolve favoritesProvider).
      await h.container.read(favoritesProvider.stream).first;
      // Risolve FutureProvider.
      await h.container.read(installedAppsProvider.future);

      final result = h.container.read(favoriteAppsProvider);
      expect(result.map((a) => a.packageName), ['com.a', 'com.c']);
    });

    test('skips favorites for apps no longer installed', () async {
      final installed = [
        InstalledAppInfo(packageName: 'com.a', label: 'Alpha'),
      ];
      final h = buildTestContainer(extra: [
        installedAppsProvider.overrideWith((ref) async => installed),
      ]);
      addTearDown(h.dispose);

      // com.b è favorito ma NON è installato — deve essere filtrato.
      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.db.addFavorite('com.b', label: 'Beta');

      await h.container.read(favoritesProvider.stream).first;
      await h.container.read(installedAppsProvider.future);

      final result = h.container.read(favoriteAppsProvider);
      expect(result.map((a) => a.packageName), ['com.a']);
    });

    test('returns empty list when no favorites are stored', () async {
      final installed = [
        InstalledAppInfo(packageName: 'com.a', label: 'Alpha'),
      ];
      final h = buildTestContainer(extra: [
        installedAppsProvider.overrideWith((ref) async => installed),
      ]);
      addTearDown(h.dispose);

      await h.container.read(favoritesProvider.stream).first;
      await h.container.read(installedAppsProvider.future);

      expect(h.container.read(favoriteAppsProvider), isEmpty);
    });
  });

  group('FavoritesController', () {
    test('add() persists a favorite in db', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final controller = h.container.read(favoritesControllerProvider);
      await controller.add('com.x', label: 'X');

      final favs = await h.db.getFavorites();
      expect(favs.map((f) => f.packageName), ['com.x']);
    });

    test('remove() deletes a favorite from db', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.addFavorite('com.x', label: 'X');
      await h.db.addFavorite('com.y', label: 'Y');

      final controller = h.container.read(favoritesControllerProvider);
      await controller.remove('com.x');

      final favs = await h.db.getFavorites();
      expect(favs.map((f) => f.packageName), ['com.y']);
    });

    test('reorder() rewrites the orderIndex values', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'A');
      await h.db.addFavorite('com.b', label: 'B');
      await h.db.addFavorite('com.c', label: 'C');

      final controller = h.container.read(favoritesControllerProvider);
      await controller.reorder(['com.c', 'com.a', 'com.b']);

      final favs = await h.db.getFavorites();
      expect(favs.map((f) => f.packageName), ['com.c', 'com.a', 'com.b']);
    });
  });
}
