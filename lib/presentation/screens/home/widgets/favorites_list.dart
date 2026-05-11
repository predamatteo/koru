import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/favorites_provider.dart';
import '../../all_apps/widgets/app_list_view.dart';

/// Lista favoriti reorderable. Tap = lancia app, long press = menu contestuale.
///
/// IMPORTANTE: la lista ha scroll proprio (non più `shrinkWrap +
/// NeverScrollableScrollPhysics` dentro un `SingleChildScrollView` esterno).
/// Quel pattern impediva l'auto-scroll durante il drag perché
/// `ReorderableListView` ha bisogno di una `Scrollable` propria per scrollare
/// quando il dito si avvicina ai bordi. Il caller deve dare a questo widget
/// un'altezza limitata (es. Expanded o SizedBox).
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
            onLongPress: () => showAppContextMenu(
              context: context,
              app: app,
              isFavorite: true,
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
      },
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
