import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/permission_channel.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

/// Gestione permessi post-onboarding (utente che aveva premuto "Skip for now"
/// o vuole verificare lo stato). Riutilizza il pattern di onboarding con
/// WidgetsBindingObserver che refresha su resume dopo ritorno da Settings.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
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
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: KoruPullToRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Koru only runs on your device. Nothing ever leaves it.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KoruColors.textSecondary),
            ),
            const SizedBox(height: 16),
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
            _PermTile(
              title: 'Notification listener',
              subtitle: 'Filter notifications from blocked apps (Phase 2).',
              granted: s?.notificationListener ?? false,
              required: false,
              onGrant: () => _channel.openNotificationListenerSettings(),
            ),
          ],
        ),
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
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(title),
          if (required && !granted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: KoruColors.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Required',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: KoruColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(subtitle),
      trailing: granted
          ? const SizedBox.shrink()
          : TextButton(onPressed: onGrant, child: const Text('Grant')),
    );
  }
}
