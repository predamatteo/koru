import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/koru_type.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../../data/database/app_database.dart';
import '../../../../domain/entities/launcher_item.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/favorites_provider.dart';
import '../../all_apps/widgets/app_list_view.dart';

/// Lista top-level del launcher: app preferite sciolte + cartelle, riordinabili.
///
/// - Tap su app = lancia. Long-press su app = menu contestuale.
/// - Tap su cartella = espandi/collassa inline (le app appaiono indentate
///   sotto la riga). Long-press su cartella = menu rinomina/elimina.
/// - Drag (long-press + trascina) = riordina gli elementi top-level; app
///   sciolte e cartelle condividono lo stesso ordinamento.
///
/// **Composizione "Inchiostro e ore"**: parole su una pagina, non righe di una
/// lista. Serif editoriale allineato a sinistra, e il *peso segue la
/// posizione* — il primo preferito è il più grande e opaco, gli ultimi
/// arretrano ([_sizeFor] / [_opacityFor]). Riordinare non sposta soltanto: ri-
/// pesa. Il blocco è ancorato al FONDO, sotto il pollice, non centrato
/// verticalmente come in ogni altro launcher (vedi [_topPadding]).
///
/// IMPORTANTE: la lista ha scroll proprio (non `shrinkWrap +
/// NeverScrollableScrollPhysics` dentro un `SingleChildScrollView` esterno).
/// Quel pattern impediva l'auto-scroll durante il drag perché
/// `ReorderableListView` ha bisogno di una `Scrollable` propria per scrollare
/// quando il dito si avvicina ai bordi. Il caller deve dare a questo widget
/// un'altezza limitata (es. Expanded o SizedBox).
///
/// Lo stato espanso/collassato delle cartelle è locale al widget (non
/// persistito): all'apertura del launcher le cartelle partono collassate, per
/// una home pulita.
class FavoritesList extends ConsumerStatefulWidget {
  const FavoritesList({required this.phase, super.key});

  final LauncherPhase phase;

  @override
  ConsumerState<FavoritesList> createState() => _FavoritesListState();
}

/// Scala tipografica dei preferiti: il peso è funzione della posizione, non
/// una proprietà dell'app. Oltre il quinto elemento la scala si appiattisce
/// invece di sparire.
const List<double> _kSizes = [35, 30, 27, 24, 22];
const List<double> _kOpacities = [1, 0.92, 0.84, 0.74, 0.64];

/// Righe indentate di una cartella aperta.
const double _kFolderChildSize = 21;
const double _kFolderChildGap = 14;
const double _kFolderIndent = 22;

double _sizeFor(int index) => _kSizes[math.min(index, _kSizes.length - 1)];
double _opacityFor(int index) =>
    _kOpacities[math.min(index, _kOpacities.length - 1)];

class _FavoritesListState extends ConsumerState<FavoritesList> {
  final Set<int> _expandedFolderIds = {};

  void _toggleFolder(int id) {
    setState(() {
      if (!_expandedFolderIds.remove(id)) _expandedFolderIds.add(id);
    });
  }

  /// Mappa un item top-level nel riferimento usato da `reorderTopLevel`
  /// (esattamente uno tra packageName / folderId valorizzato).
  ({String? packageName, int? folderId}) _refOf(LauncherItem item) =>
      switch (item) {
        LauncherLooseApp(:final app) => (
            packageName: app.packageName,
            folderId: null,
          ),
        LauncherFolderItem(:final id) => (packageName: null, folderId: id),
      };

  /// Ancoraggio al fondo. Il CSS del design è `flex:1; justify-content:
  /// flex-end`: quando i preferiti non riempiono lo spazio scendono verso il
  /// pollice invece di restare in alto. Qui l'equivalente è un padding
  /// superiore pari allo spazio avanzato — che è `0` esattamente nel caso in
  /// cui il contenuto scrolla, quindi non interferisce mai con lo scroll né
  /// con gli offset del drag-reorder.
  ///
  /// Le altezze sono deterministiche perché le decidiamo noi: ogni riga è
  /// `font-size` (line-height 1) + il respiro della fascia oraria. La
  /// `TextScaler` di sistema scala solo la parte tipografica, come fa il testo
  /// vero, così l'ancoraggio resta corretto anche a font-scale 1.5x.
  double _topPadding(
    List<LauncherItem> items,
    double viewportHeight,
    TextScaler textScaler,
  ) {
    var content = 0.0;
    for (var i = 0; i < items.length; i++) {
      content += textScaler.scale(_sizeFor(i)) + widget.phase.gap;
      final item = items[i];
      if (item is LauncherFolderItem && _expandedFolderIds.contains(item.id)) {
        final rows = item.apps.isEmpty ? 1 : item.apps.length;
        content +=
            rows * (textScaler.scale(_kFolderChildSize) + _kFolderChildGap);
      }
    }
    return math.max(0, viewportHeight - content - _kBottomPadding);
  }

  static const double _kBottomPadding = 4;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(launcherItemsProvider);
    if (items.isEmpty) {
      return _EmptyFavoritesHint(phase: widget.phase);
    }

    final controller = ref.watch(favoritesControllerProvider);
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    final folders =
        ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) => ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.only(
          top: _topPadding(items, constraints.maxHeight, textScaler),
          bottom: _kBottomPadding,
        ),
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          final reordered = List<LauncherItem>.from(items);
          final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(adjusted, moved);
          controller.reorderTopLevel(
            reordered.map(_refOf).toList(growable: false),
          );
        },
        itemBuilder: (context, index) {
          final item = items[index];
          return switch (item) {
            LauncherLooseApp(:final app) => _LooseAppTile(
                key: ValueKey('app:${app.packageName}'),
                index: index,
                phase: widget.phase,
                app: app,
                folders: folders,
                controller: controller,
                blocking: blocking,
              ),
            LauncherFolderItem() => _FolderTile(
                key: ValueKey('folder:${item.id}'),
                index: index,
                phase: widget.phase,
                folder: item,
                folders: folders,
                expanded: _expandedFolderIds.contains(item.id),
                onToggle: () => _toggleFolder(item.id),
                onMenu: () => _showFolderMenu(item, controller),
                controller: controller,
                blocking: blocking,
              ),
          };
        },
      ),
    );
  }

  Future<void> _showFolderMenu(
    LauncherFolderItem folder,
    FavoritesController controller,
  ) {
    return showStyledSheet(
      context: context,
      title: folder.name,
      subtitle: 'Folder options',
      builder: (ctx) => [
        SheetActionTile(
          icon: Icons.drive_file_rename_outline,
          label: 'Rename folder',
          onTap: () async {
            Navigator.pop(ctx);
            if (!context.mounted) return;
            final newName =
                await showFolderNameDialog(context, initial: folder.name);
            if (newName != null) {
              await controller.renameFolder(folder.id, newName);
            }
          },
        ),
        SheetActionTile(
          icon: Icons.folder_delete_outlined,
          label: 'Delete folder',
          subtitle: 'Its apps return to the home',
          danger: true,
          onTap: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            Navigator.pop(ctx);
            await controller.deleteFolder(folder.id);
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(
              SnackBar(
                content: Text('Deleted folder "${folder.name}"'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Riga di una app preferita sciolta (fuori da ogni cartella).
///
/// Il respiro della fascia oraria è metà sopra e metà sotto il testo invece
/// che tutto fra una riga e l'altra: visivamente identico, ma ogni parola
/// diventa un bersaglio alto `font-size + gap` — 45-65px — invece dei 22px
/// della sola riga di testo.
class _LooseAppTile extends StatelessWidget {
  const _LooseAppTile({
    required super.key,
    required this.index,
    required this.phase,
    required this.app,
    required this.folders,
    required this.controller,
    required this.blocking,
  });

  final int index;
  final LauncherPhase phase;
  final LauncherApp app;
  final List<LauncherFolder> folders;
  final FavoritesController controller;
  final BlockingChannel blocking;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: InkWell(
        onTap: () => blocking.launchApp(app.packageName),
        onLongPress: () => showAppContextMenu(
          context: context,
          app: InstalledAppInfo(packageName: app.packageName, label: app.label),
          isFavorite: true,
          currentFolderId: null,
          folders: folders,
          favoritesController: controller,
          blocking: blocking,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: phase.gap / 2,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              app.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KoruType.serif(
                size: _sizeFor(index),
                color: phase.ink,
                opacity: _opacityFor(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Riga di una cartella + (se espansa) le app indentate sotto. È un unico item
/// top-level: il drag sull'header trascina la cartella intera.
///
/// Il conteggio è mono a due cifre (`03`) e il segno di apertura è `+` / `−`
/// in accento: dove prima c'erano due chevron di Material, ora c'è un carattere.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required super.key,
    required this.index,
    required this.phase,
    required this.folder,
    required this.folders,
    required this.expanded,
    required this.onToggle,
    required this.onMenu,
    required this.controller,
    required this.blocking,
  });

  final int index;
  final LauncherPhase phase;
  final LauncherFolderItem folder;
  final List<LauncherFolder> folders;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onMenu;
  final FavoritesController controller;
  final BlockingChannel blocking;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableDelayedDragStartListener(
          index: index,
          child: InkWell(
            onTap: onToggle,
            onLongPress: onMenu,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: phase.gap / 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KoruType.serif(
                        size: _sizeFor(index),
                        color: phase.ink,
                        opacity: _opacityFor(index),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${folder.count}'.padLeft(2, '0'),
                    style: KoruType.mono(
                      size: 10,
                      color: phase.ink2,
                      trackEm: phase.trackEm,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    expanded ? '−' : '+',
                    style: KoruType.mono(size: 11, color: phase.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: phase.hair)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (folder.apps.isEmpty)
                    _FolderChild(phase: phase, label: 'Empty folder')
                  else
                    for (final app in folder.apps)
                      _FolderChild(
                        phase: phase,
                        label: app.label,
                        onTap: () => blocking.launchApp(app.packageName),
                        onLongPress: () => showAppContextMenu(
                          context: context,
                          app: InstalledAppInfo(
                            packageName: app.packageName,
                            label: app.label,
                          ),
                          isFavorite: true,
                          currentFolderId: folder.id,
                          folders: folders,
                          favoritesController: controller,
                          blocking: blocking,
                        ),
                      ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Riga di una app dentro una cartella aperta: indentata oltre la hairline,
/// più piccola e in `ink2` — è chiaramente subordinata alla parola sopra.
class _FolderChild extends StatelessWidget {
  const _FolderChild({
    required this.phase,
    required this.label,
    this.onTap,
    this.onLongPress,
  });

  final LauncherPhase phase;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(
          left: _kFolderIndent,
          right: 24,
          top: _kFolderChildGap / 2,
          bottom: _kFolderChildGap / 2,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KoruType.serif(
              size: _kFolderChildSize,
              color: phase.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavoritesHint extends StatelessWidget {
  const _EmptyFavoritesHint({required this.phase});

  final LauncherPhase phase;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Text(
          'Long-press an app in the drawer to add it here.',
          style: KoruType.serif(
            size: 22,
            height: 1.25,
            color: phase.ink2,
          ),
        ),
      ),
    );
  }
}
