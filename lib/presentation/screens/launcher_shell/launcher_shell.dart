import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/statistics_providers.dart';

/// Indice del tab Statistiche, nell'ordine dei `destinations` qui sotto (e
/// delle `StatefulShellBranch` in `app_router.dart`: home, profiles, stats,
/// settings). Le due liste vanno lette insieme — se una cambia ordine, cambia
/// anche questo.
const int _statsTabIndex = 2;

/// Shell principale con NavigationBar floating arrotondata.
/// Usa StatefulNavigationShell per preservare lo stato di navigazione di ogni tab.
class LauncherShell extends ConsumerWidget {
  const LauncherShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(WidgetRef ref, int index) {
    // Entrare nelle Statistiche le riporta sempre su oggi. Il branch resta
    // montato nell'IndexedStack, quindi la schermata non ha un `initState` da
    // cui accorgersi di essere tornata in primo piano: il punto di ingresso è
    // questo tap. Vedi [resetStatsView].
    if (index == _statsTabIndex) resetStatsView(ref.read);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // Disabilita l'ink splash rettangolare che appariva al tap
              // dentro ogni NavigationDestination — lasciamo solo l'indicator
              // animato, senza highlight semi-trasparente.
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                ),
                child: NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => _onTap(ref, index),
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
      ),
    );
  }
}
