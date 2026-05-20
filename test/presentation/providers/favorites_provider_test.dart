import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
    test('resolves favorites from db preserving orderIndex order', () async {
      final h = buildTestContainer(extra: [
        installedPackageNamesProvider
            .overrideWith((ref) async => {'com.a', 'com.b', 'com.c'}),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.db.addFavorite('com.c', label: 'Charlie');

      await h.container.read(favoriteEntriesProvider.stream).first;
      await h.container.read(installedPackageNamesProvider.future);

      final result = h.container.read(favoriteAppsProvider);
      expect(result.map((a) => a.packageName), ['com.a', 'com.c']);
      // Label risolti dal DB (tabella applications), non dal native.
      expect(result.map((a) => a.label), ['Alpha', 'Charlie']);
    });

    test('hides favorites for apps no longer installed', () async {
      final h = buildTestContainer(extra: [
        // com.b favorito ma NON nel set installato → filtrato.
        installedPackageNamesProvider.overrideWith((ref) async => {'com.a'}),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.db.addFavorite('com.b', label: 'Beta');

      await h.container.read(favoriteEntriesProvider.stream).first;
      await h.container.read(installedPackageNamesProvider.future);

      final result = h.container.read(favoriteAppsProvider);
      expect(result.map((a) => a.packageName), ['com.a']);
    });

    test('returns empty list when no favorites are stored', () async {
      final h = buildTestContainer(extra: [
        installedPackageNamesProvider.overrideWith((ref) async => {'com.a'}),
      ]);
      addTearDown(h.dispose);

      await h.container.read(installedPackageNamesProvider.future);

      expect(h.container.read(favoriteAppsProvider), isEmpty);
    });

    // Regressione del flicker ricorrente (73d174c → e3c930d → 1c98db7): i
    // favoriti NON devono mai collassare a vuoto per uno stato di loading del
    // provider delle app installate. Il fix li disaccoppia (vengono dal DB) e
    // filtra le disinstallate SOLO quando il set di package e' pronto e non
    // vuoto; finche' non lo e', li mostra tutti.
    test('shows favorites unfiltered while installed names not ready', () async {
      // installedPackageNamesProvider resta pending → valueOrNull == null.
      final completer = Completer<Set<String>>();
      final h = buildTestContainer(extra: [
        installedPackageNamesProvider.overrideWith((ref) => completer.future),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.db.addFavorite('com.b', label: 'Beta');
      await h.container.read(favoriteEntriesProvider.stream).first;
      keepProviderAlive(h.container, favoriteAppsProvider);

      // Set non ancora caricato → mostra TUTTI i favoriti (mai vuoto).
      expect(
        h.container.read(favoriteAppsProvider).map((a) => a.packageName),
        ['com.a', 'com.b'],
        reason: 'durante il loading del set i favoriti restano visibili',
      );

      // A set caricato (com.b risulta disinstallato) filtra correttamente.
      completer.complete({'com.a'});
      await h.container.read(installedPackageNamesProvider.future);
      expect(
        h.container.read(favoriteAppsProvider).map((a) => a.packageName),
        ['com.a'],
      );
    });

    test('keeps favorites visible while installed names reloads', () async {
      var completer = Completer<Set<String>>();
      final h = buildTestContainer(extra: [
        installedPackageNamesProvider.overrideWith((ref) => completer.future),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'Alpha');
      await h.container.read(favoriteEntriesProvider.stream).first;
      keepProviderAlive(h.container, favoriteAppsProvider);

      completer.complete({'com.a'});
      await h.container.read(installedPackageNamesProvider.future);
      expect(
        h.container.read(favoriteAppsProvider).map((a) => a.packageName),
        ['com.a'],
      );

      // Reload: loading-con-previous → valueOrNull mantiene il set.
      completer = Completer<Set<String>>();
      h.container.invalidate(installedPackageNamesProvider);
      await Future<void>.delayed(Duration.zero);
      final reloading = h.container.read(installedPackageNamesProvider);
      expect(reloading.isLoading, isTrue, reason: 'deve essere in reload');
      expect(reloading.hasValue, isTrue, reason: 'previous conservato');
      expect(
        h.container.read(favoriteAppsProvider).map((a) => a.packageName),
        ['com.a'],
        reason: 'i favoriti restano visibili durante il reload',
      );

      completer.complete({'com.a'});
      await h.container.read(installedPackageNamesProvider.future);
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
