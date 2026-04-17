import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/favorites_provider.dart';

/// Lista favoriti reorderable. Tap = lancia app, long press = rimuovi.
class FavoritesList extends ConsumerWidget {
  const FavoritesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteAppsProvider);
    if (favorites.isEmpty) {
      return const _EmptyFavoritesHint();
    }

    final controller = ref.watch(favoritesControllerProvider);
    final blocking = ref.watch(platformChannelServiceProvider).blocking;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: favorites.length,
      onReorder: (oldIndex, newIndex) {
        final updated = List<InstalledAppInfo>.from(favorites);
        final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
        final moved = updated.removeAt(oldIndex);
        updated.insert(adjusted, moved);
        controller.reorder(updated.map((a) => a.packageName).toList());
      },
      itemBuilder: (context, index) {
        final app = favorites[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(app.packageName),
          index: index,
          child: InkWell(
            onTap: () => blocking.launchApp(app.packageName),
            onLongPress: () => _showRemoveSheet(context, app, controller),
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
      },
    );
  }

  void _showRemoveSheet(
    BuildContext context,
    InstalledAppInfo app,
    FavoritesController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star_border, color: KoruColors.danger),
              title: const Text('Remove from favorites'),
              onTap: () {
                controller.remove(app.packageName);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
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
