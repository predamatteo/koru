import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
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
  Set<String>? _selected;
  bool _loaded = false;

  Future<void> _hydrate() async {
    if (_loaded) return;
    final profile = await ref.read(profileByIdProvider(widget.profileId).future);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _selected = profile?.apps.map((a) => a.packageName).toSet() ?? <String>{};
    });
  }

  Future<void> _save() async {
    if (_selected == null) return;
    await ref
        .read(profileRepositoryProvider)
        .setAppsForProfile(widget.profileId, _selected!.toList(growable: false));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select apps'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (apps) {
          if (_selected == null) return const SizedBox.shrink();
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final app = apps[i];
              final checked = _selected!.contains(app.packageName);
              return CheckboxListTile(
                value: checked,
                title: Text(app.label),
                subtitle: Text(
                  app.packageName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KoruColors.textSecondary,
                      ),
                ),
                onChanged: (v) {
                  setState(() {
                    if (v ?? false) {
                      _selected!.add(app.packageName);
                    } else {
                      _selected!.remove(app.packageName);
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
