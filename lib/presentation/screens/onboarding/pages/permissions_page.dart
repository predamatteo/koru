import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/permission_channel.dart';

class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage>
    with WidgetsBindingObserver {
  KoruPermissionStatus? _status;

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
    final s = await _channel.checkAllPermissions();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text('Permissions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Koru only runs on your device. Nothing ever leaves it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
          _PermTile(
            title: 'Accessibility',
            subtitle: 'Detect when you open a distracting app.',
            granted: s?.accessibility ?? false,
            required: true,
            onGrant: () => _channel.openAccessibilitySettings(),
          ),
          _PermTile(
            title: 'Usage access',
            subtitle: 'Read time spent per app.',
            granted: s?.usageStats ?? false,
            required: true,
            onGrant: () => _channel.openUsageStatsSettings(),
          ),
          _PermTile(
            title: 'Display over other apps',
            subtitle: 'Show the mindful overlay.',
            granted: s?.overlay ?? false,
            required: true,
            onGrant: () => _channel.openOverlaySettings(),
          ),
          _PermTile(
            title: 'Battery optimization',
            subtitle: 'Keep the blocking engine alive in background.',
            granted: s?.batteryOptimizationIgnored ?? false,
            required: false,
            onGrant: () => _channel.requestDisableBatteryOptimization(),
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  const _PermTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.required,
    required this.onGrant,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final bool required;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        granted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: granted ? KoruColors.success : KoruColors.textSecondary,
      ),
      title: Row(
        children: [
          Text(title),
          if (required && !granted) ...[
            const SizedBox(width: 8),
            Chip(
              label: const Text('Required'),
              padding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      trailing: granted
          ? const SizedBox.shrink()
          : TextButton(onPressed: onGrant, child: const Text('Grant')),
    );
  }
}
