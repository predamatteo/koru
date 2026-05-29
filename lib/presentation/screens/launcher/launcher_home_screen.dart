import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/launcher_swipe_actions_provider.dart';
import '../home/widgets/circle_clock_widget.dart';
import '../home/widgets/favorites_list.dart';
import 'widgets/launcher_shortcut_buttons.dart';

/// Velocità minima (px/s) perché un drag conti come swipe intenzionale: filtra
/// i micro-movimenti senza richiedere flick troppo aggressivi.
const double _kSwipeVelocityThreshold = 320;

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
    // Pre-warm di [installedAppsProvider]: quando Koru e' launcher di
    // default il cold start parte direttamente qui (defaultRouteName ==
    // '/launcher') saltando [HomeScreen] che gia' pre-warmava. Senza
    // questo subscribe il primo accesso a "All apps" dopo un process kill
    // (frequente per un launcher tenuto in background) trova
    // [installedAppsProvider] senza previous → ramo `loading()` di .when
    // → spinner 1-3s (durata `getInstalledApps` nativo). Subscribed qui,
    // il fetch parte mentre l'utente vede clock + favoriti, e al tap su
    // "All apps" la lista e' gia' cached. Stesso pattern di
    // home_screen.dart:34. Risolve di riflesso anche il bug analogo in
    // [LauncherShortcutPickerScreen].
    ref.watch(installedAppsProvider);

    return Scaffold(
      body: SafeArea(
        // GestureDetector a livello schermo per le swipe personalizzabili.
        // `opaque` così riceve i drag anche sulle zone "vuote" del layout.
        // Gli swipe ORIZZONTALI non confliggono con la FavoritesList (che
        // gestisce solo drag verticali + long-press reorder). Lo swipe
        // VERTICALE verso l'alto vince l'arena nelle zone non scrollabili
        // (clock in alto, area bottoni in basso): partendo "dal basso" come
        // da design il gesto parte fuori dalla lista e funziona; se parte
        // sopra la lista, è la lista a scrollare (comportamento atteso).
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) => _onHorizontalDrag(context, ref, d),
          onVerticalDragEnd: (d) => _onVerticalDrag(context, ref, d),
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
            // FavoritesList gestisce ora il proprio scroll (richiesto per
            // l'auto-scroll durante il drag-reorder). L'Expanded le dà
            // l'altezza limitata che serve perché ReorderableListView non
            // può vivere senza vincoli verticali.
            const Expanded(child: FavoritesList()),
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
      ),
    );
  }

  void _onHorizontalDrag(
      BuildContext context, WidgetRef ref, DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < _kSwipeVelocityThreshold) return;
    // primaryVelocity > 0 = movimento verso destra.
    _handleSwipe(
      context,
      ref,
      v > 0 ? LauncherSwipeDirection.right : LauncherSwipeDirection.left,
    );
  }

  void _onVerticalDrag(BuildContext context, WidgetRef ref, DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    // Solo swipe verso l'alto (velocity negativa). Lo swipe verso il basso non
    // è mappato (3 direzioni: su / sinistra / destra).
    if (v >= -_kSwipeVelocityThreshold) return;
    _handleSwipe(context, ref, LauncherSwipeDirection.up);
  }

  void _handleSwipe(
      BuildContext context, WidgetRef ref, LauncherSwipeDirection dir) {
    final action = ref.read(launcherSwipeActionsProvider)[dir] ??
        LauncherSwipeAction.none;
    switch (action.type) {
      case LauncherSwipeActionType.none:
        return;
      case LauncherSwipeActionType.allApps:
        context.push(KoruRoutes.launcherDrawer);
      case LauncherSwipeActionType.appSearch:
        context.push('${KoruRoutes.launcherDrawer}?focus=search');
      case LauncherSwipeActionType.openApp:
        final pkg = action.packageName;
        if (pkg != null && pkg.isNotEmpty) {
          ref.read(platformChannelServiceProvider).blocking.launchApp(pkg);
        }
    }
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
