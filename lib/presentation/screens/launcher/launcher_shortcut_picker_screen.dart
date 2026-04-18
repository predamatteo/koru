import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/launcher_shortcuts_provider.dart';

/// Picker per sostituire la app collegata a uno shortcut del launcher.
/// Ricevuta `slot` via query param ("left" | "right") della route.
class LauncherShortcutPickerScreen extends ConsumerStatefulWidget {
  const LauncherShortcutPickerScreen({super.key, required this.slot});

  final LauncherShortcutSlot slot;

  @override
  ConsumerState<LauncherShortcutPickerScreen> createState() =>
      _LauncherShortcutPickerScreenState();
}

class _LauncherShortcutPickerScreenState
    extends ConsumerState<LauncherShortcutPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _title() => widget.slot == LauncherShortcutSlot.left
      ? 'Left shortcut'
      : 'Right shortcut';

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final currentPkg = ref.watch(effectiveShortcutPackageProvider(widget.slot));
    final notifier = ref.read(launcherShortcutsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          IconButton(
            tooltip: 'Reset to default',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await notifier.clear(widget.slot);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shortcut reset to default')),
                );
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (apps) {
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? apps
              : apps
                  .where((a) =>
                      a.label.toLowerCase().contains(q) ||
                      a.packageName.toLowerCase().contains(q))
                  .toList(growable: false);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final app = filtered[i];
              final isCurrent = app.packageName == currentPkg;
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
                onTap: () async {
                  await notifier.set(widget.slot, app.packageName);
                  if (context.mounted) context.pop();
                },
              );
            },
          );
        },
      ),
    );
  }
}
