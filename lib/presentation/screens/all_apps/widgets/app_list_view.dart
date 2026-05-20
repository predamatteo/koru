import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
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

/// Bottom sheet contestuale per un'app: favorite/unfavorite, app info, uninstall.
/// Condiviso tra drawer e lista favoriti.
Future<void> showAppContextMenu({
  required BuildContext context,
  required InstalledAppInfo app,
  required bool isFavorite,
  required FavoritesController favoritesController,
  required BlockingChannel blocking,
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
