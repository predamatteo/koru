import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/launcher_swipe_actions_provider.dart';

/// Picker per assegnare un'azione a una direzione di swipe del launcher.
/// In cima le azioni "speciali" (nessuna / tutte le app / ricerca), sotto la
/// lista delle app installate da cui scegliere — escluse quelle distraenti
/// (profili blocklist + limiti, vedi [distractingAppsProvider]).
///
/// Replica il pattern di [LauncherShortcutPickerScreen]: search con debounce
/// 150ms e stale-while-revalidate su [installedAppsProvider].
class LauncherSwipePickerScreen extends ConsumerStatefulWidget {
  const LauncherSwipePickerScreen({super.key, required this.direction});

  final LauncherSwipeDirection direction;

  @override
  ConsumerState<LauncherSwipePickerScreen> createState() =>
      _LauncherSwipePickerScreenState();
}

class _LauncherSwipePickerScreenState
    extends ConsumerState<LauncherSwipePickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounce identico al picker degli shortcut: evita di refiltrare l'intera
  /// lista app a ogni keystroke (jank su device modesti). 150ms = percepito
  /// istantaneo.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = value);
    });
  }

  String _title() => switch (widget.direction) {
        LauncherSwipeDirection.up => 'Swipe up',
        LauncherSwipeDirection.left => 'Swipe left',
        LauncherSwipeDirection.right => 'Swipe right',
      };

  Future<void> _pick(LauncherSwipeAction action) async {
    await ref
        .read(launcherSwipeActionsProvider.notifier)
        .set(widget.direction, action);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Stale-while-revalidate: come AllAppsScreen / shortcut picker, la lista
    // cached resta visibile durante i reload (post-resume / PACKAGE_*).
    final appsAsync = ref.watch(installedAppsProvider);
    final current = ref.watch(swipeActionForProvider(widget.direction));
    final distracting = ref.watch(distractingAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search apps',
                prefixIcon: const Icon(Icons.search,
                    color: KoruColors.textSecondary),
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
      body: appsAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (apps) {
          final q = _query.trim().toLowerCase();
          // Escludi le app distraenti, poi applica la query di ricerca.
          final filtered = apps
              .where((a) => !distracting.contains(a.packageName))
              .where((a) =>
                  q.isEmpty ||
                  a.label.toLowerCase().contains(q) ||
                  a.packageName.toLowerCase().contains(q))
              .toList(growable: false);

          // Le azioni speciali compaiono solo quando non si sta cercando
          // un'app per nome (la ricerca riguarda la lista app).
          final showActions = q.isEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
            children: [
              if (showActions) ...[
                _ActionTile(
                  icon: Icons.block,
                  label: 'None',
                  selected: current.type == LauncherSwipeActionType.none,
                  onTap: () => _pick(LauncherSwipeAction.none),
                ),
                _ActionTile(
                  icon: Icons.apps_outlined,
                  label: 'All apps',
                  selected: current.type == LauncherSwipeActionType.allApps,
                  onTap: () => _pick(const LauncherSwipeAction(
                      LauncherSwipeActionType.allApps)),
                ),
                _ActionTile(
                  icon: Icons.search,
                  label: 'App search',
                  selected: current.type == LauncherSwipeActionType.appSearch,
                  onTap: () => _pick(const LauncherSwipeAction(
                      LauncherSwipeActionType.appSearch)),
                ),
                const Divider(height: 16),
              ],
              ...filtered.map((app) {
                final isCurrent =
                    current.type == LauncherSwipeActionType.openApp &&
                        current.packageName == app.packageName;
                return ListTile(
                  leading: app.iconBytes != null
                      ? Image.memory(app.iconBytes!, width: 40, height: 40)
                      : const SizedBox(width: 40),
                  title: Text(app.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(app.packageName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: isCurrent
                      ? const Icon(Icons.check, color: KoruColors.primary)
                      : null,
                  onTap: () => _pick(LauncherSwipeAction(
                      LauncherSwipeActionType.openApp,
                      packageName: app.packageName)),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: KoruColors.textSecondary),
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check, color: KoruColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
