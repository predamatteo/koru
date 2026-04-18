import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shell principale con NavigationBar floating arrotondata.
/// Usa StatefulNavigationShell per preservare lo stato di navigazione di ogni tab.
class LauncherShell extends StatelessWidget {
  const LauncherShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: KoruColors.textSecondary.withValues(alpha: 0.08),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onTap,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: l10n.tabHome,
                    tooltip: l10n.tabHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.shield_outlined),
                    selectedIcon: const Icon(Icons.shield),
                    label: l10n.tabProfiles,
                    tooltip: l10n.tabProfiles,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.self_improvement_outlined),
                    selectedIcon: const Icon(Icons.self_improvement),
                    label: l10n.tabFocus,
                    tooltip: l10n.tabFocus,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.insights_outlined),
                    selectedIcon: const Icon(Icons.insights),
                    label: l10n.tabStats,
                    tooltip: l10n.tabStats,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: l10n.tabSettings,
                    tooltip: l10n.tabSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
