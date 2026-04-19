import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/profile_providers.dart';

/// Seleziona le app da bloccare (blocklist) o consentire (allowlist) per un profilo.
class SetBlockedAppsScreen extends ConsumerStatefulWidget {
  const SetBlockedAppsScreen({super.key, required this.profileId});

  final int profileId;

  @override
  ConsumerState<SetBlockedAppsScreen> createState() =>
      _SetBlockedAppsScreenState();
}

class _SetBlockedAppsScreenState extends ConsumerState<SetBlockedAppsScreen> {
  Set<String> _selected = <String>{};
  bool _loaded = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Pre-fetch della lista app: anche se il provider è cached, la prima
    // lettura (primo entering) è asincrona — triggeriamo subito così Flutter
    // inizia il MethodChannel call in parallelo alla transition di navigazione.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(installedAppsProvider);
      _hydrate();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_loaded) return;
    // refresh forzato: profileByIdProvider è una FutureProvider cached,
    // quindi senza invalidation espliciva ritornerebbe stale data tra
    // visite ripetute.
    final profile = await ref
        .refresh(profileByIdProvider(widget.profileId).future);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      // Filtra solo le relations effettivamente attive: senza filtro
      // includevamo anche relations create per in-app sections o overlay
      // custom (isEnabled=false), che apparivano "pre-selezionate" senza
      // essere realmente bloccate.
      _selected = profile?.apps
              .where((a) => a.isEnabled)
              .map((a) => a.packageName)
              .toSet() ??
          <String>{};
    });
  }

  Future<void> _save() async {
    await ref
        .read(profileRepositoryProvider)
        .setAppsForProfile(widget.profileId, _selected.toList(growable: false));
    // Invalidate profileByIdProvider: l'editor (e ulteriori visite a
    // questa screen) devono vedere i dati appena salvati, non lo snapshot
    // cached.
    ref.invalidate(profileByIdProvider(widget.profileId));
    if (mounted) context.pop();
  }

  List<InstalledAppInfo> _filter(List<InstalledAppInfo> apps) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return apps;
    return apps
        .where((a) =>
            a.label.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select apps'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
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
          if (!_loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final filtered = _filter(apps);
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No apps matching "$_query"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: KoruColors.textSecondary,
                    ),
              ),
            );
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final app = filtered[i];
              final checked = _selected.contains(app.packageName);
              return CheckboxListTile(
                value: checked,
                activeColor: KoruColors.primary,
                checkColor: Colors.white,
                side: const BorderSide(
                  color: KoruColors.textSecondary,
                  width: 1.5,
                ),
                secondary: app.iconBytes != null
                    ? Image.memory(app.iconBytes!, width: 40, height: 40)
                    : const SizedBox(width: 40),
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
                onChanged: (v) {
                  setState(() {
                    if (v ?? false) {
                      _selected.add(app.packageName);
                    } else {
                      _selected.remove(app.packageName);
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}
