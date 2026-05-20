import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/launcher_item.dart';
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

  group('launcher folders (db)', () {
    test('addFavorite places new favorites in the shared top-level space',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'A'); // loose, idx 0
      await h.db.createFolder('Work'); // folder, idx 1
      await h.db.addFavorite('com.c', label: 'C'); // loose, idx 2

      final favA =
          (await h.db.getFavorites()).firstWhere((f) => f.packageName == 'com.a');
      final favC =
          (await h.db.getFavorites()).firstWhere((f) => f.packageName == 'com.c');
      final folder = (await h.db.getFolders()).single;

      expect(favA.orderIndex, 0);
      expect(folder.orderIndex, 1);
      expect(favC.orderIndex, 2);
    });

    test('addFavorite with folderId stores the app inside the folder',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final fid = await h.db.createFolder('Work');
      await h.db.addFavorite('com.b', label: 'B', folderId: fid);

      final fav = (await h.db.getFavorites()).single;
      expect(fav.folderId, fid);
      expect(fav.orderIndex, 0); // primo nello spazio interno alla cartella
    });

    test('setFavoriteFolder moves a favorite in and back out of a folder',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'A');
      final fid = await h.db.createFolder('Work');

      await h.db.setFavoriteFolder('com.a', fid);
      expect(
        (await h.db.getFavorites()).single.folderId,
        fid,
      );

      await h.db.setFavoriteFolder('com.a', null);
      expect(
        (await h.db.getFavorites()).single.folderId,
        isNull,
      );
    });

    test('deleteFolder returns its apps to the home and removes the folder',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final fid = await h.db.createFolder('Work');
      await h.db.addFavorite('com.b', label: 'B', folderId: fid);
      await h.db.addFavorite('com.a', label: 'A'); // loose

      await h.db.deleteFolder(fid);

      final favs = await h.db.getFavorites();
      expect(favs.map((f) => f.packageName).toSet(), {'com.a', 'com.b'});
      expect(favs.every((f) => f.folderId == null), isTrue,
          reason: 'le app della cartella eliminata tornano sciolte');
      expect(await h.db.getFolders(), isEmpty);
    });

    test('reorderTopLevel rewrites order across both apps and folders',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'A'); // idx 0
      final fid = await h.db.createFolder('Work'); // idx 1

      // Inverti: prima la cartella, poi l'app.
      await h.db.reorderTopLevel([
        (packageName: null, folderId: fid),
        (packageName: 'com.a', folderId: null),
      ]);

      expect((await h.db.getFolders()).single.orderIndex, 0);
      expect(
        (await h.db.getFavorites()).single.orderIndex,
        1,
      );
    });
  });

  group('launcherItemsProvider', () {
    test('interleaves loose apps and folders, grouping apps under their folder',
        () async {
      final h = buildTestContainer(extra: [
        installedPackageNamesProvider
            .overrideWith((ref) async => {'com.a', 'com.b', 'com.c'}),
      ]);
      addTearDown(h.dispose);

      await h.db.addFavorite('com.a', label: 'A'); // loose, idx 0
      final fid = await h.db.createFolder('Work'); // folder, idx 1
      await h.db.addFavorite('com.b', label: 'B', folderId: fid); // in folder
      await h.db.addFavorite('com.c', label: 'C'); // loose, idx 2

      await h.container.read(favoriteEntriesProvider.stream).first;
      await h.container.read(foldersProvider.stream).first;
      await h.container.read(installedPackageNamesProvider.future);
      keepProviderAlive(h.container, launcherItemsProvider);

      final items = h.container.read(launcherItemsProvider);
      expect(items.length, 3);

      expect(items[0], isA<LauncherLooseApp>());
      expect((items[0] as LauncherLooseApp).app.packageName, 'com.a');

      expect(items[1], isA<LauncherFolderItem>());
      final folder = items[1] as LauncherFolderItem;
      expect(folder.name, 'Work');
      expect(folder.apps.map((a) => a.packageName), ['com.b']);

      expect(items[2], isA<LauncherLooseApp>());
      expect((items[2] as LauncherLooseApp).app.packageName, 'com.c');
    });

    test('filters out uninstalled apps but keeps the folder', () async {
      final h = buildTestContainer(extra: [
        // com.b (dentro la cartella) non è installata → filtrata.
        installedPackageNamesProvider.overrideWith((ref) async => {'com.x'}),
      ]);
      addTearDown(h.dispose);

      final fid = await h.db.createFolder('Work');
      await h.db.addFavorite('com.b', label: 'B', folderId: fid);
      await h.db.addFavorite('com.x', label: 'X', folderId: fid);

      await h.container.read(favoriteEntriesProvider.stream).first;
      await h.container.read(foldersProvider.stream).first;
      await h.container.read(installedPackageNamesProvider.future);
      keepProviderAlive(h.container, launcherItemsProvider);

      final items = h.container.read(launcherItemsProvider);
      final folder = items.single as LauncherFolderItem;
      expect(folder.apps.map((a) => a.packageName), ['com.x']);
    });
  });
}
