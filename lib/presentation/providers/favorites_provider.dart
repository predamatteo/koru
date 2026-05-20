import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../domain/entities/launcher_item.dart';
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
final favoriteEntriesProvider = StreamProvider<
    List<({String packageName, String label, int? folderId, int orderIndex})>>(
  (ref) {
    ref.keepAlive();
    final db = ref.watch(appDatabaseProvider);
    return db.watchFavoritesWithLabels();
  },
);

/// Stream delle cartelle del launcher (ordine `orderIndex`). `keepAlive` come
/// [favoriteEntriesProvider]: stesso ciclo di vita della home del launcher.
final foldersProvider = StreamProvider<List<LauncherFolder>>((ref) {
  ref.keepAlive();
  final db = ref.watch(appDatabaseProvider);
  return db.watchFolders();
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
      const <({String packageName, String label, int? folderId, int orderIndex})>[];
  final installedNames =
      ref.watch(installedPackageNamesProvider).valueOrNull;
  final canFilter = installedNames != null && installedNames.isNotEmpty;
  return entries
      .where((e) => !canFilter || installedNames.contains(e.packageName))
      .map((e) => InstalledAppInfo(packageName: e.packageName, label: e.label))
      .toList(growable: false);
});

/// Lista top-level della home launcher: app preferite **sciolte** + **cartelle**,
/// interlacciate per `orderIndex`, con le app di ogni cartella già ordinate.
///
/// Stessa disciplina anti-flicker di [favoriteAppsProvider]: i dati arrivano dal
/// DB locale (mai dal volatile `installedAppsProvider`) e le app disinstallate
/// si filtrano SOLO quando [installedPackageNamesProvider] è caricato e non
/// vuoto — durante un loading la lista non deve mai collassare a vuoto.
final launcherItemsProvider = Provider<List<LauncherItem>>((ref) {
  final entries = ref.watch(favoriteEntriesProvider).valueOrNull ??
      const <({String packageName, String label, int? folderId, int orderIndex})>[];
  final folders =
      ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];
  final installedNames = ref.watch(installedPackageNamesProvider).valueOrNull;
  final canFilter = installedNames != null && installedNames.isNotEmpty;
  bool installed(String pkg) => !canFilter || installedNames.contains(pkg);

  // Partiziona i favoriti: sciolti (top-level) vs dentro una cartella.
  final loose = <({int orderIndex, LauncherApp app})>[];
  final byFolder = <int, List<({int orderIndex, LauncherApp app})>>{};
  for (final e in entries) {
    if (!installed(e.packageName)) continue;
    final app = LauncherApp(packageName: e.packageName, label: e.label);
    if (e.folderId == null) {
      loose.add((orderIndex: e.orderIndex, app: app));
    } else {
      (byFolder[e.folderId!] ??= []).add((orderIndex: e.orderIndex, app: app));
    }
  }

  // Fonde app sciolte e cartelle in un unico ordinamento top-level.
  final top = <({int orderIndex, LauncherItem item})>[];
  for (final l in loose) {
    top.add((orderIndex: l.orderIndex, item: LauncherLooseApp(l.app)));
  }
  for (final f in folders) {
    final apps = (byFolder[f.id] ?? <({int orderIndex, LauncherApp app})>[])
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    top.add((
      orderIndex: f.orderIndex,
      item: LauncherFolderItem(
        id: f.id,
        name: f.name,
        apps: apps.map((e) => e.app).toList(growable: false),
      ),
    ));
  }
  top.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return top.map((e) => e.item).toList(growable: false);
});

class FavoritesController {
  FavoritesController(this._db);

  final AppDatabase _db;

  Future<void> add(String packageName, {String? label, int? folderId}) =>
      _db.addFavorite(packageName, label: label, folderId: folderId);
  Future<void> remove(String packageName) => _db.removeFavorite(packageName);
  Future<void> reorder(List<String> orderedPackageNames) =>
      _db.reorderFavorites(orderedPackageNames);

  // --- Cartelle ---
  Future<int> createFolder(String name) => _db.createFolder(name);
  Future<void> renameFolder(int id, String name) =>
      _db.renameFolder(id, name);
  Future<void> deleteFolder(int id) => _db.deleteFolder(id);

  /// Sposta un preferito in una cartella (`folderId`) o lo riporta sciolto
  /// (`folderId == null`).
  Future<void> moveToFolder(String packageName, int? folderId) =>
      _db.setFavoriteFolder(packageName, folderId);

  /// Riordina gli item top-level (mix di app sciolte e cartelle).
  Future<void> reorderTopLevel(
    List<({String? packageName, int? folderId})> items,
  ) =>
      _db.reorderTopLevel(items);
}

final favoritesControllerProvider = Provider<FavoritesController>(
  (ref) => FavoritesController(ref.watch(appDatabaseProvider)),
);
