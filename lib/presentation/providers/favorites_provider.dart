import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../platform/blocking_channel.dart';
import 'app_list_provider.dart';

/// Stream dei package names favoriti (ordine orderIndex crescente).
final favoritesProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchFavorites().map((rows) => rows.map((r) => r.packageName).toList(growable: false));
});

/// Risolve i package favoriti in oggetti InstalledAppInfo
/// preservando l'ordine di favoritesProvider e filtrando app non più installate.
final favoriteAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final favPackages = ref.watch(favoritesProvider).valueOrNull ?? const <String>[];
  final installed = ref.watch(installedAppsProvider).valueOrNull ?? const <InstalledAppInfo>[];
  final byPkg = {for (final a in installed) a.packageName: a};
  return favPackages
      .map((p) => byPkg[p])
      .whereType<InstalledAppInfo>()
      .toList(growable: false);
});

class FavoritesController {
  FavoritesController(this._db);

  final AppDatabase _db;

  Future<void> add(String packageName, {String? label}) =>
      _db.addFavorite(packageName, label: label);
  Future<void> remove(String packageName) => _db.removeFavorite(packageName);
  Future<void> reorder(List<String> orderedPackageNames) =>
      _db.reorderFavorites(orderedPackageNames);
}

final favoritesControllerProvider = Provider<FavoritesController>(
  (ref) => FavoritesController(ref.watch(appDatabaseProvider)),
);
