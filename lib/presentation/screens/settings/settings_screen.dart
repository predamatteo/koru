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
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
        children: [
          _Section(
            label: 'Appearance',
            children: [
              _Tile(
                icon: Icons.palette_outlined,
                title: 'Font',
                onTap: () => context.push('/settings/font'),
              ),
              _SwitchTile(
                icon: Icons.invert_colors_outlined,
                title: 'Monochrome',
                value: monochrome,
                onChanged: (v) =>
                    ref.read(monochromeProvider.notifier).setEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            label: 'Launcher',
            children: [
              _Tile(
                icon: Icons.home_outlined,
                title: 'Set as default',
                onTap: () => context.push('/settings/launcher'),
              ),
              _Tile(
                icon: Icons.apps_outlined,
                title: 'App personalization',
                onTap: () => context.push('/settings/app-personalization'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            label: 'Discipline',
            children: [
              _Tile(
                icon: Icons.shield_outlined,
                title: 'Strict mode',
                onTap: () => context.push('/settings/strict-mode'),
              ),
              _Tile(
                icon: Icons.vpn_key_outlined,
                title: 'Backdoor codes',
                onTap: () => context.push('/settings/backdoor'),
              ),
              _Tile(
                icon: Icons.hourglass_bottom_outlined,
                title: 'App daily limits',
                onTap: () => context.push('/settings/app-limits'),
              ),
              _Tile(
                icon: Icons.notifications_off_outlined,
                title: 'Notification filter',
                onTap: () => context.push('/settings/notification-filter'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            label: 'Permissions',
            children: [
              _Tile(
                icon: Icons.verified_user_outlined,
                title: 'Permissions',
                onTap: () => context.push('/settings/permissions'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            label: 'About',
            children: [
              _Tile(
                icon: Icons.info_outline,
                title: 'About Koru',
                onTap: () => context.push('/settings/about'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section container: uppercase accent label + grouped card con i tile.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: KoruColors.primary.withAlpha(220),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: KoruColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 52),
                    child: Container(
                      height: 1,
                      color: KoruColors.surfaceElevated,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tile standard: icona leading verde, titolo, opzionale valore + chevron.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: KoruColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: KoruColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: KoruColors.textSecondary.withAlpha(140),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile con Switch trailing (niente chevron).
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: KoruColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: KoruColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: KoruColors.primary,
              inactiveThumbColor: KoruColors.textSecondary,
              inactiveTrackColor: KoruColors.backgroundBase,
            ),
          ],
        ),
      ),
    );
  }
}
