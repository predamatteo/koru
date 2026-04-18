import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../providers/monochrome_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monochrome = ref.watch(monochromeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: kBottomNavClearance),
        children: [
          const _SectionLabel('Appearance'),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text('Font'),
            subtitle: const Text('Pick the typography you prefer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/font'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.invert_colors_outlined),
            title: const Text('Monochrome'),
            subtitle: const Text('Remove color from Koru UI and the launcher'),
            value: monochrome,
            onChanged: (v) => ref.read(monochromeProvider.notifier).setEnabled(v),
          ),
          const Divider(height: 1),
          const _SectionLabel('Launcher'),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Koru as launcher'),
            subtitle: const Text('Replace your default home screen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/launcher'),
          ),
          ListTile(
            leading: const Icon(Icons.apps_outlined),
            title: const Text('App personalization'),
            subtitle: const Text('Rename or hide apps in the drawer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/app-personalization'),
          ),
          const Divider(height: 1),
          const _SectionLabel('Permissions'),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Permissions'),
            subtitle: const Text('Grant or re-check Accessibility, Usage, Overlay…'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/permissions'),
          ),
          const Divider(height: 1),
          const _SectionLabel('Discipline'),
          ListTile(
            leading: const Icon(Icons.lock_outlined),
            title: const Text('Strict mode'),
            subtitle: const Text('Lock Settings, Recent apps, Uninstall'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/strict-mode'),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Backdoor code'),
            subtitle: const Text('Emergency unblock'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/backdoor'),
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom_outlined),
            title: const Text('App daily limits'),
            subtitle: const Text('Set a minutes cap per app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/app-limits'),
          ),
          const Divider(height: 1),
          const _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Koru'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
