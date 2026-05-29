import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../platform/permission_channel.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/launcher_swipe_actions_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

class LauncherSettingsScreen extends ConsumerStatefulWidget {
  const LauncherSettingsScreen({super.key});

  @override
  ConsumerState<LauncherSettingsScreen> createState() =>
      _LauncherSettingsScreenState();
}

class _LauncherSettingsScreenState extends ConsumerState<LauncherSettingsScreen>
    with WidgetsBindingObserver {
  bool _modeEnabled = false;
  bool _isDefault = false;

  PermissionChannel get _channel =>
      ref.read(platformChannelServiceProvider).permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final e = await _channel.isLauncherModeEnabled();
    final d = await _channel.isDefaultLauncher();
    if (!mounted) return;
    setState(() {
      _modeEnabled = e;
      _isDefault = d;
    });
  }

  Future<void> _toggleMode(bool v) async {
    await _channel.setLauncherModeEnabled(v);
    setState(() => _modeEnabled = v);
    if (v && !_isDefault) {
      await _channel.openDefaultLauncherSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Launcher')),
      body: KoruPullToRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: _isDefault ? KoruColors.successContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isDefault ? Icons.check_circle : Icons.home_outlined,
                          color: _isDefault
                              ? KoruColors.success
                              : KoruColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isDefault
                                ? 'Koru is your default launcher'
                                : 'Koru is not your default launcher',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _modeEnabled,
              onChanged: _toggleMode,
              title: const Text('Make Koru selectable as launcher'),
              subtitle: const Text(
                'Enables the HOME activity. You still need to pick Koru '
                'in the system chooser.',
              ),
            ),
            if (_modeEnabled) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open system launcher picker'),
                onPressed: () => _channel.openDefaultLauncherSettings(),
              ),
            ],
            const SizedBox(height: 24),
            _buildSwipeSection(),
          ],
        ),
      ),
    );
  }

  /// Sezione "Swipe gestures": assegna un'azione a swipe su / sinistra /
  /// destra sulla home del launcher. Le azioni si applicano solo quando Koru
  /// è il launcher di default (la home con le gesture è la `LauncherHomeScreen`).
  Widget _buildSwipeSection() {
    final actions = ref.watch(launcherSwipeActionsProvider);
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const [];

    String labelFor(LauncherSwipeAction action) {
      switch (action.type) {
        case LauncherSwipeActionType.none:
          return 'None';
        case LauncherSwipeActionType.allApps:
          return 'All apps';
        case LauncherSwipeActionType.appSearch:
          return 'App search';
        case LauncherSwipeActionType.openApp:
          final pkg = action.packageName;
          for (final a in apps) {
            if (a.packageName == pkg) return a.label;
          }
          return pkg ?? 'App';
      }
    }

    Widget tile(String title, LauncherSwipeDirection dir, IconData icon) {
      final action = actions[dir] ?? LauncherSwipeAction.none;
      final dirParam = dir.name; // up | left | right
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: KoruColors.textSecondary),
        title: Text(title),
        subtitle: Text(labelFor(action)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('${KoruRoutes.launcherSwipe}?dir=$dirParam'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Swipe gestures',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Assign an action to home-screen swipes. Distracting apps '
          '(blocked or limited) are not selectable.',
          style: TextStyle(color: KoruColors.textSecondary),
        ),
        const SizedBox(height: 8),
        tile('Swipe up', LauncherSwipeDirection.up, Icons.keyboard_arrow_up),
        tile('Swipe left', LauncherSwipeDirection.left,
            Icons.keyboard_arrow_left),
        tile('Swipe right', LauncherSwipeDirection.right,
            Icons.keyboard_arrow_right),
      ],
    );
  }
}
