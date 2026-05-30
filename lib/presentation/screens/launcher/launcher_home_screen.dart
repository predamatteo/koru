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
class LauncherHomeScreen extends ConsumerStatefulWidget {
  const LauncherHomeScreen({super.key});

  @override
  ConsumerState<LauncherHomeScreen> createState() => _LauncherHomeScreenState();
}

class _LauncherHomeScreenState extends ConsumerState<LauncherHomeScreen>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sottoscrizione (una sola volta per route) al RouteObserver del navigator
    // root: `subscribe` chiama subito `didPush()` per la route corrente, quindi
    // l'esclusione gesture si attiva al primo mount. Guardia su route diversa:
    // un didChangeDependencies mentre il launcher è COPERTO (es. cambio tema
    // con /home in cima) non deve ri-sottoscrivere e ri-attivare l'override.
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) launcherRouteObserver.unsubscribe(this);
      launcherRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void dispose() {
    launcherRouteObserver.unsubscribe(this);
    _setGestureExclusion(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── RouteAware: l'override gesture vive SOLO quando il launcher è in cima ──
  // Il tasto "K" fa push di /home SOPRA il launcher (che resta montato sotto):
  // senza questo scoping l'esclusione resterebbe attiva dentro l'app, bloccando
  // back e home di sistema. didPushNext (coperto) → off; didPopNext / didPush
  // (riscoperto o primo mount) → on.
  @override
  void didPush() => _setGestureExclusion(true);

  @override
  void didPopNext() => _setGestureExclusion(true);

  @override
  void didPushNext() => _setGestureExclusion(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Su resume ri-applichiamo SOLO se il launcher è la route corrente: alcuni
    // OEM resettano gli exclusion rects dopo background/config change, ma se
    // l'utente è su un'altra route (es. /home) NON dobbiamo riattivare.
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      _setGestureExclusion(true);
    }
  }

  void _setGestureExclusion(bool enabled) {
    ref
        .read(platformChannelServiceProvider)
        .permission
        .setLauncherGestureExclusion(enabled);
  }

  @override
  Widget build(BuildContext context) {
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
          onHorizontalDragEnd: _onHorizontalDrag,
          onVerticalDragEnd: _onVerticalDrag,
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
            // Area centrale: lista favoriti (testo centrato) affiancata dalle
            // frecce di navigazione laterali. Le frecce sostituiscono gli hint
            // testuali sx/dx: stessa azione dello swipe, senza label. La
            // FavoritesList gestisce il proprio scroll (richiesto per
            // l'auto-scroll durante il drag-reorder); l'Expanded esterno le dà
            // l'altezza limitata che serve perché ReorderableListView non può
            // vivere senza vincoli verticali. Gli slot freccia hanno larghezza
            // fissa (anche quando vuoti) così la lista resta centrata simmetrica.
            Expanded(
              child: Row(
                children: [
                  // La freccia segue il VERSO DEL DITO, non punta verso il
                  // bordo. Lo swipe-RIGHT (dito sx→dx) parte dal bordo SINISTRO
                  // e l'icona punta a destra `›` (verso del movimento); lo
                  // swipe-LEFT (dito dx→sx) parte dal bordo DESTRO e punta a
                  // sinistra `‹`. Entrambe le frecce puntano quindi verso il
                  // centro, seguendo la direzione del gesto.
                  _buildSideArrow(
                    LauncherSwipeDirection.right,
                    Icons.chevron_right,
                  ),
                  const Expanded(child: FavoritesList()),
                  _buildSideArrow(
                    LauncherSwipeDirection.left,
                    Icons.chevron_left,
                  ),
                ],
              ),
            ),
            _buildSwipeHints(),
            const LauncherShortcutButtons(),
            const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Freccia di navigazione laterale per gli swipe sx/dx. Slot a larghezza
  /// fissa: se la direzione non ha azione assegnata resta uno spazio vuoto
  /// (così la lista al centro non si sposta quando una sola freccia è attiva).
  /// Tappabile: esegue la stessa azione dello swipe, così l'accesso resta
  /// possibile anche dove la gesture di sistema interferisce. Nessuna label —
  /// solo l'icona freccia.
  Widget _buildSideArrow(LauncherSwipeDirection dir, IconData icon) {
    const slotWidth = 44.0;
    final action =
        ref.watch(launcherSwipeActionsProvider)[dir] ?? LauncherSwipeAction.none;
    if (action.type == LauncherSwipeActionType.none) {
      return const SizedBox(width: slotWidth);
    }
    return SizedBox(
      width: slotWidth,
      child: _SideNavArrow(icon: icon, onTap: () => _handleSwipe(dir)),
    );
  }

  /// Hint per lo swipe verso l'alto (di norma "All apps"), al posto del vecchio
  /// bottone "All apps". Le direzioni sx/dx sono ora rese come frecce laterali
  /// (vedi [_buildSideArrow]). Tappabile: esegue la stessa azione dello swipe,
  /// così l'accesso resta possibile anche dove la gesture di sistema
  /// interferisce. Swipe-su disattivato → spazio minimo (niente riga vuota).
  Widget _buildSwipeHints() {
    final actions = ref.watch(launcherSwipeActionsProvider);
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const [];

    String labelFor(LauncherSwipeAction action) {
      switch (action.type) {
        case LauncherSwipeActionType.none:
          return '';
        case LauncherSwipeActionType.allApps:
          return 'All apps';
        case LauncherSwipeActionType.appSearch:
          return 'Search';
        case LauncherSwipeActionType.openApp:
          final pkg = action.packageName;
          for (final a in apps) {
            if (a.packageName == pkg) return a.label;
          }
          return pkg ?? 'App';
      }
    }

    final up = actions[LauncherSwipeDirection.up] ?? LauncherSwipeAction.none;
    if (up.type == LauncherSwipeActionType.none) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: _SwipeHint(
          icon: Icons.keyboard_arrow_up,
          label: labelFor(up),
          onTap: () => _handleSwipe(LauncherSwipeDirection.up),
        ),
      ),
    );
  }

  void _onHorizontalDrag(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < _kSwipeVelocityThreshold) return;
    // primaryVelocity > 0 = movimento verso destra.
    _handleSwipe(
      v > 0 ? LauncherSwipeDirection.right : LauncherSwipeDirection.left,
    );
  }

  void _onVerticalDrag(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    // Solo swipe verso l'alto (velocity negativa). Lo swipe verso il basso non
    // è mappato (3 direzioni: su / sinistra / destra).
    if (v >= -_kSwipeVelocityThreshold) return;
    _handleSwipe(LauncherSwipeDirection.up);
  }

  void _handleSwipe(LauncherSwipeDirection dir) {
    final action =
        ref.read(launcherSwipeActionsProvider)[dir] ?? LauncherSwipeAction.none;
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

/// Freccia di navigazione laterale (sx/dx): icona chevron centrata in uno slot
/// alto e tappabile, senza label. Stile sobrio coerente con [_SwipeHint].
class _SideNavArrow extends StatelessWidget {
  const _SideNavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Center(
        child: Icon(
          icon,
          size: 32,
          color: KoruColors.textSecondary,
        ),
      ),
    );
  }
}

/// Hint minimale per uno swipe: freccia direzionale + label dell'azione.
/// Tappabile (esegue l'azione). Stile sobrio coerente col launcher.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: KoruColors.textSecondary),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
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
