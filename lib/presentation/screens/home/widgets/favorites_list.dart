import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
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
/// IMPORTANTE: la lista ha scroll proprio (non più `shrinkWrap +
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
  const FavoritesList({super.key});

  @override
  ConsumerState<FavoritesList> createState() => _FavoritesListState();
}

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

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(launcherItemsProvider);
    if (items.isEmpty) {
      return const _EmptyFavoritesHint();
    }

    final controller = ref.watch(favoritesControllerProvider);
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    final folders =
        ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              app: app,
              folders: folders,
              controller: controller,
              blocking: blocking,
            ),
          LauncherFolderItem() => _FolderTile(
              key: ValueKey('folder:${item.id}'),
              index: index,
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
    );
  }

  Future<void> _showFolderMenu(
    LauncherFolderItem folder,
    FavoritesController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      folder.name,
                      style: Theme.of(ctx).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename folder'),
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
            ListTile(
              leading:
                  const Icon(Icons.folder_delete_outlined, color: KoruColors.danger),
              title: const Text('Delete folder'),
              subtitle: const Text('Its apps return to the home'),
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
        ),
      ),
    );
  }
}

/// Riga di una app preferita sciolta (fuori da ogni cartella).
class _LooseAppTile extends StatelessWidget {
  const _LooseAppTile({
    required super.key,
    required this.index,
    required this.app,
    required this.folders,
    required this.controller,
    required this.blocking,
  });

  final int index;
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  app.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
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
    required this.folder,
    required this.folders,
    required this.expanded,
    required this.onToggle,
    required this.onMenu,
    required this.controller,
    required this.blocking,
  });

  final int index;
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
      children: [
        ReorderableDelayedDragStartListener(
          index: index,
          child: InkWell(
            onTap: onToggle,
            onLongPress: onMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(folder.name, style: theme.textTheme.titleMedium),
                  ),
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 22,
                    color: KoruColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${folder.count}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: KoruColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          if (folder.apps.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 40, right: 24, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Empty folder',
                  style: TextStyle(color: KoruColors.textSecondary),
                ),
              ),
            )
          else
            for (final app in folder.apps)
              InkWell(
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
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 40, right: 24, top: 12, bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.label,
                          style: theme.textTheme.titleMedium,
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

class _EmptyFavoritesHint extends StatelessWidget {
  const _EmptyFavoritesHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Long-press an app in the drawer to add it here.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: KoruColors.textSecondary,
            ),
      ),
    );
  }
}
