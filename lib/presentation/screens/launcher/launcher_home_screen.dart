import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/router/app_router.dart';
import '../home/widgets/circle_clock_widget.dart';
import '../home/widgets/favorites_list.dart';
import 'widgets/launcher_shortcut_buttons.dart';

/// Schermata launcher: clock minimalista + favoriti + 2 shortcut
/// personalizzabili (phone / camera di default) + link "All apps" e "Koru".
///
/// Mostrata SOLO quando Koru è lanciato via HOME intent (cioè è stato
/// scelto come launcher di default). Accessibile sulla route `/launcher`,
/// che vive FUORI dallo shell con bottom navigation.
class LauncherHomeScreen extends ConsumerWidget {
  const LauncherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const CircleClockWidget(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [FavoritesList()],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => context.push(KoruRoutes.launcherDrawer),
                  icon: const Icon(Icons.apps_outlined,
                      color: KoruColors.textSecondary),
                  label: const Text(
                    'All apps',
                    style: TextStyle(
                        color: KoruColors.textSecondary, letterSpacing: 1),
                  ),
                ),
                const SizedBox(width: 24),
                TextButton.icon(
                  onPressed: () => context.push(KoruRoutes.home),
                  icon: const Icon(Icons.settings_outlined,
                      color: KoruColors.textSecondary),
                  label: const Text(
                    'Koru',
                    style: TextStyle(
                        color: KoruColors.textSecondary, letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const LauncherShortcutButtons(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
