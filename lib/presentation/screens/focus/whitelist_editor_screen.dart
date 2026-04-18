import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/focus_whitelist_provider.dart';

/// Editor della whitelist di app lasciate usabili durante Quick Block o
/// Pomodoro. Default: Koru + launcher + phone + camera + SMS + clock +
/// emergency. L'utente può aggiungere qualsiasi altra app tappandola.
class WhitelistEditorScreen extends ConsumerStatefulWidget {
  const WhitelistEditorScreen({super.key, required this.mode});

  final FocusMode mode;

  @override
  ConsumerState<WhitelistEditorScreen> createState() =>
      _WhitelistEditorScreenState();
}

class _WhitelistEditorScreenState
    extends ConsumerState<WhitelistEditorScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _title() => switch (widget.mode) {
        FocusMode.quickBlock => 'Quick block whitelist',
        FocusMode.pomodoro => 'Pomodoro whitelist',
      };

  @override
  Widget build(BuildContext context) {
    final whitelist = ref.watch(focusWhitelistProvider(widget.mode));
    final notifier = ref.read(focusWhitelistProvider(widget.mode).notifier);
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await notifier.resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Whitelist reset')),
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
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: KoruColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'Apps in this list stay usable during a focus session. '
                  'Everything else is blocked until the timer ends.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KoruColors.textSecondary,
                        height: 1.4,
                      ),
                ),
              ),
              for (final app in filtered)
                CheckboxListTile(
                  value: whitelist.contains(app.packageName),
                  title: Text(app.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KoruColors.textSecondary,
                        ),
                  ),
                  onChanged: (_) => notifier.toggle(app.packageName),
                ),
            ],
          );
        },
      ),
    );
  }
}
