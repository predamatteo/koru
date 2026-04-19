import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/router/app_router.dart';
import '../home/widgets/circle_clock_widget.dart';
import '../home/widgets/favorites_list.dart';
import 'widgets/launcher_shortcut_buttons.dart';

/// Schermata launcher: clock minimalista + favoriti + 2 shortcut
/// personalizzabili (phone / camera di default) + link "All apps" e "K"
/// (scorciatoia a Koru nella top-bar).
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
            // Top bar con "K" logo-shortcut (rimpiazzabile con icona vera).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _KoruShortcut(
                    onTap: () => context.push(KoruRoutes.home),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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

/// Placeholder circolare con la lettera "K" — da rimpiazzare con il
/// logo spirale Koru vero quando sarà disponibile.
class _KoruShortcut extends StatelessWidget {
  const _KoruShortcut({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KoruColors.primary.withAlpha(40),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              'K',
              style: TextStyle(
                color: KoruColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
