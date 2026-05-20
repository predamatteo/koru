import 'dart:async';

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

    // Regressione del bug ricorrente (73d174c → e3c930d): durante un reload
    // di installedAppsProvider (invalidate da PACKAGE_* o smart-refresh al
    // resume) il provider entra in AsyncLoading.copyWithPrevious, che CONSERVA
    // il valore precedente. I favoriti devono restare visibili (stale-while-
    // revalidate). Con il vecchio `.unwrapPrevious().valueOrNull` il previous
    // veniva scartato → lista vuota per tutta la durata del rescan nativo
    // (1-3s): è lo "spariscono i preferiti" osservato sul device.
    test('keeps favorites visible while installedApps reloads', () async {
      final app = InstalledAppInfo(packageName: 'com.a', label: 'Alpha');
      var completer = Completer<List<InstalledAppInfo>>();
      final h = buildTestContainer(extra: [
        installedAppsProvider.overrideWith((ref) => completer.future),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.container.read(favoritesProvider.stream).first;
      // Tiene vivo il downstream così ricomputa ad ogni cambio di stato.
      keepProviderAlive(h.container, favoriteAppsProvider);

      // Primo load completo.
      completer.complete([app]);
      await h.container.read(installedAppsProvider.future);
      expect(
        h.container.read(favoriteAppsProvider).map((a) => a.packageName),
        ['com.a'],
      );

      // Reload: nuova fetch pendente + invalidate → loading-con-previous.
      completer = Completer<List<InstalledAppInfo>>();
      h.container.invalidate(installedAppsProvider);
      await Future<void>.delayed(Duration.zero);

      final reloading = h.container.read(installedAppsProvider);
      expect(reloading.isLoading, isTrue, reason: 'deve essere in reload');
      expect(reloading.hasValue, isTrue, reason: 'previous deve essere conservato');
      expect(
        h.container.read(favoriteAppsProvider).map((a) => a.packageName),
        ['com.a'],
        reason: 'i favoriti devono restare visibili durante il reload',
      );

      // Cleanup: completa la fetch pendente.
      completer.complete([app]);
      await h.container.read(installedAppsProvider.future);
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
