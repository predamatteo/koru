import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/app_personalization_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

/// Schermata per nascondere o rinominare le app nel drawer del launcher.
/// Trick mindful classico: togliere "Instagram" e chiamarla "Timeline"
/// riduce il brand-pull dopaminico.
class AppPersonalizationScreen extends ConsumerStatefulWidget {
  const AppPersonalizationScreen({super.key});

  @override
  ConsumerState<AppPersonalizationScreen> createState() =>
      _AppPersonalizationScreenState();
}

class _AppPersonalizationScreenState
    extends ConsumerState<AppPersonalizationScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editName(
    String pkg,
    String originalLabel,
    String? currentCustom,
  ) async {
    final controller = TextEditingController(text: currentCustom ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(originalLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Custom name',
            hintText: 'Leave empty to reset',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          if (currentCustom != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Reset'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref
        .read(appPersonalizationProvider.notifier)
        .rename(pkg, result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final personalization = ref.watch(appPersonalizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App personalization'),
        actions: [
          IconButton(
            tooltip: 'Reset all',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset personalization?'),
                  content: const Text(
                    'All custom names will be removed and all hidden apps '
                    'will become visible again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(appPersonalizationProvider.notifier).clearAll();
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search apps',
                prefixIcon: const Icon(
                  Icons.search,
                  color: KoruColors.textSecondary,
                ),
                filled: true,
                fillColor: KoruColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: KoruPullToRefresh(
        child: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (apps) {
            final q = _query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? apps
                : apps
                      .where(
                        (a) =>
                            a.label.toLowerCase().contains(q) ||
                            a.packageName.toLowerCase().contains(q),
                      )
                      .toList(growable: false);
            // Sort: rinominate/nascoste in cima
            final sorted = [...filtered]
              ..sort((a, b) {
                final aMod =
                    personalization.isHidden(a.packageName) ||
                    personalization.customName(a.packageName) != null;
                final bMod =
                    personalization.isHidden(b.packageName) ||
                    personalization.customName(b.packageName) != null;
                if (aMod == bMod) return 0;
                return aMod ? -1 : 1;
              });
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
              itemCount: sorted.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'Long-press an app to rename. Toggle the eye to hide '
                      'it from the launcher drawer (the app stays installed).',
                      style: TextStyle(
                        color: KoruColors.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final app = sorted[i - 1];
                final hidden = personalization.isHidden(app.packageName);
                final custom = personalization.customName(app.packageName);
                return ListTile(
                  leading: app.iconBytes != null
                      ? Opacity(
                          opacity: hidden ? 0.4 : 1.0,
                          child: Image.memory(
                            app.iconBytes!,
                            width: 40,
                            height: 40,
                          ),
                        )
                      : const SizedBox(width: 40),
                  title: Text(
                    custom ?? app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hidden
                          ? KoruColors.textSecondary
                          : KoruColors.textPrimary,
                      decoration: hidden ? TextDecoration.lineThrough : null,
                      fontStyle: custom != null ? FontStyle.italic : null,
                    ),
                  ),
                  subtitle: Text(
                    custom != null ? 'was: ${app.label}' : app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      hidden ? Icons.visibility_off : Icons.visibility_outlined,
                      color: hidden
                          ? KoruColors.danger
                          : KoruColors.textSecondary,
                    ),
                    onPressed: () => ref
                        .read(appPersonalizationProvider.notifier)
                        .toggleHidden(app.packageName),
                  ),
                  onLongPress: () =>
                      _editName(app.packageName, app.label, custom),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
