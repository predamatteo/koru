import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/strict_mode_channel.dart';
import '../../../providers/achievements_provider.dart';

class StrictModeScreen extends ConsumerStatefulWidget {
  const StrictModeScreen({super.key});

  @override
  ConsumerState<StrictModeScreen> createState() => _StrictModeScreenState();
}

class _StrictModeScreenState extends ConsumerState<StrictModeScreen> {
  int _mask = 0;
  bool _deviceAdminActive = false;
  bool _loaded = false;

  StrictModeChannel get _channel =>
      ref.read(platformChannelServiceProvider).strictMode;

  Future<void> _hydrate() async {
    if (_loaded) return;
    final mask = await _channel.getStrictModeOptions();
    final admin = await _channel.isDeviceAdminActive();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _mask = mask;
      _deviceAdminActive = admin;
    });
  }

  bool get _isEnabled => _mask != 0;

  Future<void> _toggleOption(int bit, bool enabled) async {
    final next = enabled ? (_mask | bit) : (_mask & ~bit);
    await _channel.setStrictModeOptions(next);
    setState(() => _mask = next);
  }

  Future<void> _toggleMaster(bool on) async {
    if (on) {
      if (!_deviceAdminActive) {
        await _channel.enableDeviceAdmin();
        // User returns: recheck status when screen resumes.
      }
      await _channel.setStrictModeOptions(StrictModeOption.allMvp);
      setState(() => _mask = StrictModeOption.allMvp);
      await ref.read(achievementEvaluationProvider.notifier).trigger();
    } else {
      await _channel.setStrictModeOptions(0);
      setState(() => _mask = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strict mode'),
        actions: [
          TextButton(
            onPressed: () => context.push('/settings/backdoor'),
            child: const Text('Backdoor'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _isEnabled ? KoruColors.dangerContainer : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isEnabled ? Icons.lock : Icons.lock_open,
                        color: _isEnabled
                            ? KoruColors.danger
                            : KoruColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEnabled
                              ? 'Strict mode is ON'
                              : 'Strict mode is OFF',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        onChanged: _toggleMaster,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isEnabled
                        ? 'Settings, Recent apps and Uninstall are locked. Use the backdoor code if you really need to disable it.'
                        : 'Enable to lock Settings, Recent apps and Uninstall. Requires Device Admin.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KoruColors.textSecondary,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('What to lock'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mask & StrictModeOption.blockSettings != 0,
            onChanged: (v) => _toggleOption(StrictModeOption.blockSettings, v),
            title: const Text('Block Settings'),
            subtitle: const Text('Prevents opening the Android Settings app.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mask & StrictModeOption.blockRecentApps != 0,
            onChanged: (v) =>
                _toggleOption(StrictModeOption.blockRecentApps, v),
            title: const Text('Block Recent apps'),
            subtitle: const Text('Prevents opening the Recent apps view.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mask & StrictModeOption.blockUninstalling != 0,
            onChanged: (v) =>
                _toggleOption(StrictModeOption.blockUninstalling, v),
            title: const Text('Block Uninstall'),
            subtitle: const Text('Prevents uninstalling Koru.'),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Device Admin'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _deviceAdminActive ? Icons.verified : Icons.warning_amber_outlined,
              color: _deviceAdminActive
                  ? KoruColors.success
                  : KoruColors.secondary,
            ),
            title: Text(
                _deviceAdminActive ? 'Device Admin active' : 'Device Admin required'),
            subtitle: Text(
              _deviceAdminActive
                  ? 'Koru has the permissions it needs.'
                  : 'Koru needs Device Admin to enforce Strict Mode.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
            ),
            trailing: _deviceAdminActive
                ? TextButton(
                    onPressed: () async {
                      await _channel.disableDeviceAdmin();
                      setState(() => _deviceAdminActive = false);
                    },
                    child: const Text('Disable'),
                  )
                : FilledButton(
                    onPressed: () async {
                      await _channel.enableDeviceAdmin();
                    },
                    child: const Text('Enable'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: KoruColors.textSecondary,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}
