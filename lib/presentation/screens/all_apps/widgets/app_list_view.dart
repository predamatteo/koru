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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KoruColors.textSecondary,
              ),
        ),
      );
    }

    final items = <Widget>[const SizedBox(height: 4)];
    for (final entry in grouped.entries) {
      items.add(_SectionHeader(letter: entry.key));
      items.addAll(entry.value.map(
        (app) => _AppTile(
          app: app,
          isFavorite: favs.contains(app.packageName),
          onTap: () => blocking.launchApp(app.packageName),
          onToggleFavorite: () {
            if (favs.contains(app.packageName)) {
              favoritesController.remove(app.packageName);
            } else {
              favoritesController.add(app.packageName);
            }
          },
        ),
      ));
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(right: 42),
      children: items,
    );
  }
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
    required this.onToggleFavorite,
  });

  final InstalledAppInfo app;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onToggleFavorite,
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
                const Icon(
                  Icons.star,
                  size: 16,
                  color: KoruColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
