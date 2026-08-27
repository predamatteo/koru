import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../../data/database/app_database.dart';
import '../../../../domain/entities/launcher_item.dart';
import '../../../../l10n/generated/app_localizations.dart';
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
/// Righe in `headlineSmall` della type scale Material 3, allineate a sinistra
/// e **ancorate al fondo** — sotto il pollice, non centrate verticalmente
/// (vedi [_topPadding]). Il respiro fra le righe è quello della fascia oraria.
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

/// Righe indentate di una cartella aperta.
const double _kFolderChildGap = 14;
const double _kFolderIndent = 24;
const double _kBottomPadding = 4;

/// Fallback usati solo per il calcolo dell'ancoraggio quando il tema non
/// definisce la voce della type scale (non succede col tema di Koru).
const double _kRowFontFallback = 24; // headlineSmall
const double _kChildFontFallback = 16; // titleMedium

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

  /// Ancoraggio al fondo: padding superiore pari allo spazio avanzato. Quando
  /// i preferiti non riempiono lo schermo scendono verso il pollice invece di
  /// restare appesi in alto; quando invece la lista scrolla, il padding è `0`
  /// e non interferisce né con lo scroll né con gli offset del drag-reorder.
  ///
  /// Le altezze sono deterministiche perché le decidiamo noi: ogni riga è
  /// `font-size` (line-height 1) più il respiro della fascia. La `TextScaler`
  /// di sistema scala solo la parte tipografica, come fa il testo vero, così
  /// l'ancoraggio resta corretto anche a font-scale 1.5x.
  double _topPadding({
    required List<LauncherItem> items,
    required double viewportHeight,
    required TextScaler textScaler,
    required double rowFontSize,
    required double childFontSize,
  }) {
    var content = 0.0;
    for (final item in items) {
      content += textScaler.scale(rowFontSize) + widget.phase.gap;
      if (item is LauncherFolderItem && _expandedFolderIds.contains(item.id)) {
        final rows = item.apps.isEmpty ? 1 : item.apps.length;
        content += rows * (textScaler.scale(childFontSize) + _kFolderChildGap);
      }
    }
    return math.max(0, viewportHeight - content - _kBottomPadding);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(launcherItemsProvider);
    if (items.isEmpty) {
      return const _EmptyFavoritesHint();
    }

    final theme = Theme.of(context);
    final rowStyle = theme.textTheme.headlineSmall?.copyWith(
      color: KoruColors.textPrimary,
      height: 1,
    );
    final childStyle = theme.textTheme.titleMedium?.copyWith(
      color: KoruColors.textSecondary,
      height: 1,
    );

    final controller = ref.watch(favoritesControllerProvider);
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    final folders =
        ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) => ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.only(
          top: _topPadding(
            items: items,
            viewportHeight: constraints.maxHeight,
            textScaler: textScaler,
            rowFontSize: rowStyle?.fontSize ?? _kRowFontFallback,
            childFontSize: childStyle?.fontSize ?? _kChildFontFallback,
          ),
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
                style: rowStyle,
                app: app,
                folders: folders,
                controller: controller,
                blocking: blocking,
              ),
            LauncherFolderItem() => _FolderTile(
                key: ValueKey('folder:${item.id}'),
                index: index,
                phase: widget.phase,
                style: rowStyle,
                childStyle: childStyle,
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
      subtitle: AppLocalizations.of(context).favoritesFolderOptions,
      builder: (ctx) => [
        SheetActionTile(
          icon: Icons.drive_file_rename_outline,
          label: AppLocalizations.of(context).favoritesRenameFolder,
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
          label: AppLocalizations.of(context).favoritesDeleteFolder,
          subtitle: AppLocalizations.of(context).favoritesDeleteFolderSubtitle,
          danger: true,
          onTap: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            // Il messaggio si compone PRIMA dell'await, come il messenger:
            // dopo la cancellazione questo `context` può essere già smontato,
            // e leggerlo lì sarebbe la stessa trappola.
            final deletedMessage =
                AppLocalizations.of(context).favoritesFolderDeleted(folder.name);
            Navigator.pop(ctx);
            await controller.deleteFolder(folder.id);
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(
              SnackBar(
                content: Text(deletedMessage),
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
/// che tutto fra una riga e l'altra: visivamente identico, ma ogni riga
/// diventa un bersaglio alto `font-size + gap` (46-54px) invece dei 24px del
/// solo testo.
class _LooseAppTile extends StatelessWidget {
  const _LooseAppTile({
    required super.key,
    required this.index,
    required this.phase,
    required this.style,
    required this.app,
    required this.folders,
    required this.controller,
    required this.blocking,
  });

  final int index;
  final LauncherPhase phase;
  final TextStyle? style;
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
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// Riga di una cartella + (se espansa) le app indentate sotto. È un unico item
/// top-level: il drag sull'header trascina la cartella intera.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required super.key,
    required this.index,
    required this.phase,
    required this.style,
    required this.childStyle,
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
  final TextStyle? style;
  final TextStyle? childStyle;
  final LauncherFolderItem folder;
  final List<LauncherFolder> folders;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onMenu;
  final FavoritesController controller;
  final BlockingChannel blocking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                children: [
                  Flexible(
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${folder.count}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: KoruColors.textSecondary),
                  ),
                  const Spacer(),
                  // Rotazione invece di due icone diverse: è la stessa freccia
                  // che gira, come ogni superficie espandibile di Material 3.
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      size: 22,
                      color: KoruColors.textSecondary,
                    ),
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
                border: Border(left: BorderSide(color: phase.edge)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (folder.apps.isEmpty)
                    _FolderChild(
                      style: childStyle,
                      label: AppLocalizations.of(context).favoritesEmptyFolder,
                    )
                  else
                    for (final app in folder.apps)
                      _FolderChild(
                        style: childStyle,
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

/// Riga di una app dentro una cartella aperta: indentata oltre il filetto,
/// più piccola e in `textSecondary` — chiaramente subordinata alla riga sopra.
class _FolderChild extends StatelessWidget {
  const _FolderChild({
    required this.style,
    required this.label,
    this.onTap,
    this.onLongPress,
  });

  final TextStyle? style;
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
            style: style,
          ),
        ),
      ),
    );
  }
}

class _EmptyFavoritesHint extends StatelessWidget {
  const _EmptyFavoritesHint();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Text(
          AppLocalizations.of(context).favoritesEmptyHint,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: KoruColors.textSecondary),
        ),
      ),
    );
  }
}
