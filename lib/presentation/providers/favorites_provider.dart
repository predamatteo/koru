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

/// Stream dei favoriti con label, risolto dal DB locale (join favorites →
/// applications). keepAlive come [favoritesProvider]: unico subscriber a
/// regime e' la home del launcher, che durante navigazioni rapide puo'
/// smontarsi per un frame.
final favoriteEntriesProvider =
    StreamProvider<List<({String packageName, String label})>>((ref) {
  ref.keepAlive();
  final db = ref.watch(appDatabaseProvider);
  return db.watchFavoritesWithLabels();
});

/// Risolve i favoriti in [InstalledAppInfo] per la home del launcher.
///
/// Ordine e label vengono dal DB locale ([favoriteEntriesProvider]: package +
/// label dalla tabella `applications`), NON dal lento `installedAppsProvider`.
/// La lista favoriti mostra solo testo (FavoritesList) e il context menu usa
/// solo label/packageName — nessuno usa l'icona — quindi non ha senso gateare
/// i favoriti sul native `getInstalledApps` (scan PackageManager + decode
/// icone, 1-3s).
///
/// Perche' il disaccoppiamento e non l'ennesimo ritocco di keepAlive/
/// valueOrNull: il flicker "favoriti spariti" e' ricomparso per 3 commit
/// (73d174c, e3c930d, 1c98db7) perche' `favoriteAppsProvider` intersecava i
/// favoriti con `installedAppsProvider`, provider VOLATILE (invalidato da
/// PACKAGE_*/smart-refresh, ricreato puro all'avvio). Qualunque suo
/// reload/dispose con previous mancante svuotava la lista → favoriti vuoti.
///
/// Filtro app disinstallate: la tabella `applications` accumula (nessun
/// hard-delete), quindi un favorito di app rimossa resterebbe. Filtriamo
/// contro [installedPackageNamesProvider] — endpoint CHEAP (~50ms, no decode
/// icone), non quello pesante. CRUCIALE: filtriamo SOLO quando il set e'
/// caricato e non vuoto; se e' null (cold start) o vuoto (glitch nativo: un
/// device ha sempre centinaia di package) mostriamo TUTTI i favoriti. Cosi'
/// la lista non puo' MAI collassare a vuoto per uno stato di loading — il
/// caso di fallimento esatto che causava il flicker. `iconBytes` resta null.
final favoriteAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final entries = ref.watch(favoriteEntriesProvider).valueOrNull ??
      const <({String packageName, String label})>[];
  final installedNames =
      ref.watch(installedPackageNamesProvider).valueOrNull;
  final canFilter = installedNames != null && installedNames.isNotEmpty;
  return entries
      .where((e) => !canFilter || installedNames.contains(e.packageName))
      .map((e) => InstalledAppInfo(packageName: e.packageName, label: e.label))
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
