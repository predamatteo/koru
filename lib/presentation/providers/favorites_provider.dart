import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../platform/blocking_channel.dart';
import 'app_list_provider.dart';

/// Stream dei package names favoriti (ordine orderIndex crescente).
///
/// `keepAlive`: in modalita' "Koru default launcher" l'unico subscriber
/// e' FavoritesList sotto LauncherHomeScreen. Durante transizioni rapide
/// (HOME intent re-emesso → `ctx.go('/launcher')` quando gia' su
/// /launcher, push/pop di /launcher/drawer, shortcut "K" verso /home) il
/// listener puo' essere brevemente smontato. Senza keepAlive il provider
/// auto-dispone e al re-subscribe il `valueOrNull` di
/// `favoriteAppsProvider` resta `null` per un frame extra (Drift
/// `.watch()` deve ri-emettere il primo snapshot) → favoriti vuoti
/// visibili per qualche centinaio di ms. Costo: < 1KB persistente (lista
/// di package name).
final favoritesProvider = StreamProvider<List<String>>((ref) {
  ref.keepAlive();
  final db = ref.watch(appDatabaseProvider);
  return db.watchFavorites().map((rows) => rows.map((r) => r.packageName).toList(growable: false));
});

/// Risolve i package favoriti in oggetti InstalledAppInfo
/// preservando l'ordine di favoritesProvider e filtrando app non più installate.
///
/// Stale-while-revalidate su [installedAppsProvider]: quando viene invalidato
/// (PACKAGE_ADDED/REMOVED/REPLACED, oppure smart refresh al resume rileva un
/// delta), Riverpod transita in AsyncLoading.copyWithPrevious — uno stato di
/// loading che CONSERVA il valore precedente. Leggiamo quindi `.valueOrNull`
/// direttamente: per contratto di AsyncValue ritorna il previous durante il
/// loading, così la lista favoriti del launcher resta visibile mentre il
/// rescan nativo (1-3s per PackageManager + decode icone) gira, e viene
/// sostituita seamless al completamento.
///
/// NB: NON usare `unwrapPrevious()` qui. Fa l'opposto di ciò che serve —
/// scarta il previous e riduce lo stato a un AsyncLoading puro, quindi
/// `.valueOrNull` tornerebbe null e i favoriti SPARIREBBERO per tutta la
/// durata del reload (bug ricorrente 73d174c → e3c930d: avevano invertito
/// la semantica dell'API credendo che `unwrapPrevious()` preservasse il
/// cached). Sul primissimo cold start (no previous) `.valueOrNull` è
/// comunque null → fallback lista vuota, corretto.
final favoriteAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final favPackages = ref.watch(favoritesProvider).valueOrNull ?? const <String>[];
  final installed =
      ref.watch(installedAppsProvider).valueOrNull ?? const <InstalledAppInfo>[];
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
