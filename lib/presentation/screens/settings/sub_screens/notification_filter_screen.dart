import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/di/providers.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/notification_filter_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

/// Permette di silenziare le notifiche da app specifiche: quando una
/// notifica arriva da un pkg selezionato, Koru la cancella
/// automaticamente prima che appaia in status bar.
///
/// Richiede che l'utente abiliti Koru in "Notification access" —
/// apriamo il deep-link al primo uso.
class NotificationFilterScreen extends ConsumerStatefulWidget {
  const NotificationFilterScreen({super.key});

  @override
  ConsumerState<NotificationFilterScreen> createState() =>
      _NotificationFilterScreenState();
}

class _NotificationFilterScreenState
    extends ConsumerState<NotificationFilterScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando l'utente torna da "Notification access" in Settings di sistema,
    // invalidiamo il provider per riflettere lo stato corrente del permesso.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationAccessGrantedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grantedAsync = ref.watch(notificationAccessGrantedProvider);
    final granted = grantedAsync.valueOrNull ?? false;
    final appsAsync = ref.watch(installedAppsProvider);
    final silencedAsync = ref.watch(notificationFilterProvider);
    final silenced = silencedAsync.valueOrNull ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification filter'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed: silenced.isEmpty
                ? null
                : () async {
                    await ref
                        .read(notificationFilterProvider.notifier)
                        .clearAll();
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
            final sorted = [...filtered]
              ..sort((a, b) {
                final aS = silenced.contains(a.packageName);
                final bS = silenced.contains(b.packageName);
                if (aS == bS) return 0;
                return aS ? -1 : 1;
              });
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
              itemCount: sorted.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) {
                  if (granted) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Notifications from the apps you silence will be '
                        'dismissed before reaching the status bar.',
                        style: TextStyle(
                          color: KoruColors.textSecondary,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return Card(
                    color: KoruColors.dangerContainer,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_outlined,
                        color: KoruColors.danger,
                      ),
                      title: const Text('Notification access required'),
                      subtitle: const Text(
                        'Enable Koru in Notification access to make silencing effective.',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await ref
                              .read(platformChannelServiceProvider)
                              .blocking
                              .openNotificationAccessSettings();
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  );
                }
                if (i == 1) return const SizedBox(height: 4);
                final app = sorted[i - 2];
                final isSilenced = silenced.contains(app.packageName);
                return CheckboxListTile(
                  value: isSilenced,
                  onChanged: (_) => ref
                      .read(notificationFilterProvider.notifier)
                      .toggle(app.packageName),
                  secondary: app.iconBytes != null
                      ? Image.memory(app.iconBytes!, width: 40, height: 40)
                      : const SizedBox(width: 40),
                  title: Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
