import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../data/database/app_database.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/favorites_provider.dart';

class AppListView extends ConsumerWidget {
  const AppListView({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(groupedAppsProvider);
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    final favs = ref.watch(favoritesProvider).valueOrNull ?? const <String>[];
    final favoritesController = ref.watch(favoritesControllerProvider);
    final folders =
        ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];

    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No matching apps',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: KoruColors.textSecondary),
        ),
      );
    }

    final items = <Widget>[const SizedBox(height: 4)];
    for (final entry in grouped.entries) {
      items.add(_SectionHeader(letter: entry.key));
      items.addAll(
        entry.value.map(
          (app) => _AppTile(
            app: app,
            isFavorite: favs.contains(app.packageName),
            onTap: () => blocking.launchApp(app.packageName),
            onLongPress: () => showAppContextMenu(
              context: context,
              app: app,
              isFavorite: favs.contains(app.packageName),
              currentFolderId: null,
              folders: folders,
              favoritesController: favoritesController,
              blocking: blocking,
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(right: 42),
      children: items,
    );
  }
}

/// Bottom sheet contestuale per un'app: favorite/unfavorite, sposta/rimuovi da
/// cartella, app info, uninstall. Condiviso tra drawer e lista favoriti.
///
/// [currentFolderId] è la cartella in cui l'app si trova ORA (valorizzato solo
/// quando il menu è aperto da dentro una cartella nel launcher): se non null
/// abilita "Remove from folder". [folders] sono le cartelle proposte come
/// destinazione da "Move to folder…".
Future<void> showAppContextMenu({
  required BuildContext context,
  required InstalledAppInfo app,
  required bool isFavorite,
  required List<LauncherFolder> folders,
  required FavoritesController favoritesController,
  required BlockingChannel blocking,
  int? currentFolderId,
}) {
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
                    app.label,
                    style: Theme.of(ctx).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              isFavorite ? Icons.star_border : Icons.star,
              color: KoruColors.primary,
            ),
            title: Text(
              isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
            onTap: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.pop(ctx);
              try {
                if (isFavorite) {
                  await favoritesController.remove(app.packageName);
                } else {
                  await favoritesController.add(
                    app.packageName,
                    label: app.label,
                  );
                }
                messenger?.hideCurrentSnackBar();
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(
                      isFavorite
                          ? 'Removed ${app.label} from favorites'
                          : 'Added ${app.label} to favorites',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text('Favorites update failed: $e'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: const Text('Move to folder…'),
            onTap: () {
              Navigator.pop(ctx);
              showMoveToFolderSheet(
                context: context,
                app: app,
                isFavorite: isFavorite,
                currentFolderId: currentFolderId,
                folders: folders,
                favoritesController: favoritesController,
              );
            },
          ),
          if (currentFolderId != null)
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Remove from folder'),
              onTap: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                Navigator.pop(ctx);
                await favoritesController.moveToFolder(app.packageName, null);
                messenger?.hideCurrentSnackBar();
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text('Moved ${app.label} back to home'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App info'),
            onTap: () {
              Navigator.pop(ctx);
              blocking.openAppInfo(app.packageName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: KoruColors.danger),
            title: const Text('Uninstall'),
            onTap: () {
              Navigator.pop(ctx);
              blocking.uninstallApp(app.packageName);
            },
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet che elenca le cartelle disponibili come destinazione, più la
/// voce "New folder…". Alla scelta assegna l'app: se non ancora favorita la
/// favorita direttamente dentro la cartella, altrimenti la sposta.
Future<void> showMoveToFolderSheet({
  required BuildContext context,
  required InstalledAppInfo app,
  required bool isFavorite,
  required int? currentFolderId,
  required List<LauncherFolder> folders,
  required FavoritesController favoritesController,
}) {
  final targets =
      folders.where((f) => f.id != currentFolderId).toList(growable: false);
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
                    'Move "${app.label}" to…',
                    style: Theme.of(ctx).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final f in targets)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f.name, overflow: TextOverflow.ellipsis),
              onTap: () async {
                Navigator.pop(ctx);
                await _assignToFolder(
                    favoritesController, app, isFavorite, f.id);
              },
            ),
          ListTile(
            leading: const Icon(
              Icons.create_new_folder_outlined,
              color: KoruColors.primary,
            ),
            title: const Text('New folder…'),
            onTap: () async {
              Navigator.pop(ctx);
              final name = await showFolderNameDialog(context);
              if (name == null) return;
              final id = await favoritesController.createFolder(name);
              await _assignToFolder(favoritesController, app, isFavorite, id);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _assignToFolder(
  FavoritesController controller,
  InstalledAppInfo app,
  bool isFavorite,
  int folderId,
) {
  if (isFavorite) {
    return controller.moveToFolder(app.packageName, folderId);
  }
  return controller.add(app.packageName, label: app.label, folderId: folderId);
}

/// Dialog per creare (`initial == null`) o rinominare una cartella. Ritorna il
/// nome digitato (trimmed, non vuoto) o `null` se annullato/vuoto.
Future<String?> showFolderNameDialog(
  BuildContext context, {
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? 'New folder' : 'Rename folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: KoruColors.textSecondary,
          letterSpacing: 3,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  final InstalledAppInfo app;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  app.label,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFavorite)
                const Icon(Icons.star, size: 16, color: KoruColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
