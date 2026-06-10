import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/diagnostics/black_box.dart';
import '../../../core/router/app_router.dart';
import '../../../platform/permission_channel.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/launcher_swipe_actions_provider.dart';
import '../../providers/open_apps_count_provider.dart';
import '../home/widgets/circle_clock_widget.dart';
import '../home/widgets/favorites_list.dart';
import 'widgets/launcher_shortcut_buttons.dart';

/// Velocità minima (px/s) perché un drag conti come swipe intenzionale: filtra
/// i micro-movimenti senza richiedere flick troppo aggressivi.
const double _kSwipeVelocityThreshold = 320;

/// One-shot per processo: marca il PRIMO frame renderizzato del launcher dopo
/// un (ri)avvio del processo = vero "time-to-usable" della home (il proxy
/// attuale è `APPS OK`, che misura il drawer, non il primo frame del launcher).
bool _launcherFirstFrameLogged = false;

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

  /// Canale permessi cacheato in [initState]: il path di teardown
  /// (`dispose` → `_setLauncherActive(false)`) NON può usare `ref` —
  /// Riverpod lancia StateError dopo l'unmount (context.mounted è già
  /// false durante dispose), il che lasciava l'esclusione gesture e lo
  /// shield recents nativi accesi e saltava removeObserver/super.dispose.
  late final PermissionChannel _permission;

  /// Overscroll-to-open: oltre questa quantità di overscroll verso il fondo
  /// (px logici, generata da un drag del dito) lo swipe-su SOPRA la lista apre
  /// "All apps". Soglia deliberata per non aprire al solo raggiungere l'ultimo
  /// item durante lo scroll. Vedi [_onFavoritesScroll].
  static const double _kOverscrollOpenThreshold = 64;
  double _overscrollUp = 0;
  bool _overscrollOpened = false;

  @override
  void initState() {
    super.initState();
    _permission = ref.read(platformChannelServiceProvider).permission;
    WidgetsBinding.instance.addObserver(this);
    if (!_launcherFirstFrameLogged) {
      _launcherFirstFrameLogged = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => BlackBox.log('DART', 'LauncherHome primo frame renderizzato'),
      );
    }
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
    _setLauncherActive(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── RouteAware: gli override "da launcher" vivono SOLO quando è in cima ──
  // Due override sono scoping-sensibili e vanno spenti quando il launcher è
  // coperto: (1) l'esclusione gesture di sistema e (2) la nav bar nascosta. Il
  // tasto "K" fa push di /home SOPRA il launcher (che resta montato sotto):
  // senza scoping l'esclusione bloccherebbe back/home di sistema e la nav bar
  // resterebbe nascosta dentro l'app. didPushNext (coperto) → off; didPopNext /
  // didPush (riscoperto o primo mount) → on.
  @override
  void didPush() => _setLauncherActive(true);

  @override
  void didPopNext() => _setLauncherActive(true);

  @override
  void didPushNext() => _setLauncherActive(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Su resume ri-applichiamo SOLO se il launcher è la route corrente: alcuni
    // OEM resettano gli exclusion rects dopo background/config change, ma se
    // l'utente è su un'altra route (es. /home) NON dobbiamo riattivare.
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      _setLauncherActive(true);
    }
  }

  /// Attiva/disattiva gli override "da launcher" (validi solo col launcher in
  /// cima): esclusione gesture di sistema + blocco gesture recents + nav bar
  /// nascosta. Vedi il commento RouteAware sopra per lo scoping.
  void _setLauncherActive(bool active) {
    _setGestureExclusion(active);
    // Blocco della gesture recents (swipe-up-and-hold): stesso scoping
    // RouteAware dell'esclusione. Il flag nativo da solo non basta quando
    // un'altra app copre Koru (la route Dart resta /launcher): la correttezza
    // la porta il guard previous-foreground del LauncherRecentsGate.
    _permission.setLauncherRecentsShield(active);
    if (active) {
      // Conteggio schede + capability dell'icona: refresh a ogni ritorno in
      // cima / resume. Pull-only: mentre il launcher è visibile nessun'altra
      // app può andare in foreground, quindi il conteggio cambia solo mentre
      // siamo coperti — questi sono esattamente i punti di rientro.
      ref.invalidate(openAppsCountProvider);
      ref.invalidate(recentsIconCapabilityProvider);
      // Nasconde SOLO la navigation bar (il pill bianco di sistema); la status
      // bar in alto (orologio/batteria) resta visibile.
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
    } else {
      // Ripristina la nav bar normale per il resto dell'app (default Android 15).
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _setGestureExclusion(bool enabled) {
    // Via canale cacheato, NON ref: vedi [_permission] (chiamato da dispose).
    _permission.setLauncherGestureExclusion(enabled);
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
        // VERTICALE verso l'alto apre "All apps": nelle zone non scrollabili
        // (clock, area bottoni) e quando la lista entra tutta (lo Scrollable
        // rifiuta il drag → vince questo GestureDetector). Quando invece la
        // lista ha contenuto scrollabile è lei a vincere l'arena e a scrollare;
        // lì l'apertura avviene tirando OLTRE il fondo (overscroll-to-open,
        // vedi [_onFavoritesScroll]).
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _onHorizontalDrag,
          onVerticalDragEnd: _onVerticalDrag,
          child: Column(
            children: [
            // Top bar: a sinistra il contatore "schede aperte" (apre il
            // gestore schede di sistema), a destra il "K" logo-shortcut
            // (rimpiazzabile con icona vera).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _RecentsShortcut(),
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
                  Expanded(child: _buildFadedFavorites()),
                  _buildSideArrow(
                    LauncherSwipeDirection.left,
                    Icons.chevron_left,
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
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

  /// Lista favoriti con bordi superiore/inferiore sfumati: quando la lista
  /// scrolla (molti preferiti) il primo/ultimo item sfuma invece di tagliarsi
  /// netto contro le righe adiacenti. Il fade è applicato qui (call-site del
  /// launcher) e non dentro [FavoritesList], così non impatta gli altri usi.
  /// Il [NotificationListener] aggiunge l'overscroll-to-open (vedi
  /// [_onFavoritesScroll]) senza toccare scroll/reorder della lista.
  Widget _buildFadedFavorites() {
    return NotificationListener<ScrollNotification>(
      onNotification: _onFavoritesScroll,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.04, 0.96, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: const FavoritesList(),
      ),
    );
  }

  /// Overscroll-to-open: quando la lista preferiti ha contenuto scrollabile il
  /// suo Scrollable vince la gesture arena sullo swipe-su del GestureDetector di
  /// schermo. Per dare comunque accesso a "All apps" da sopra la lista,
  /// intercettiamo l'overscroll OLTRE il fondo (`overscroll > 0`) prodotto da un
  /// drag del dito (`dragDetails != null`, così il rimbalzo balistico di un
  /// fling non conta) e, superata [_kOverscrollOpenThreshold], apriamo una sola
  /// volta per gesto. `return false` per non consumare la notifica: scroll,
  /// reorder e fade restano invariati. (Caso lista-corta: lo Scrollable rifiuta
  /// il drag e ad aprire è il GestureDetector parent.)
  bool _onFavoritesScroll(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _overscrollUp = 0;
      _overscrollOpened = false;
    } else if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll > 0) {
      _overscrollUp += n.overscroll;
      if (!_overscrollOpened && _overscrollUp >= _kOverscrollOpenThreshold) {
        _overscrollOpened = true;
        _openAllApps();
      }
    }
    return false;
  }

  /// Barra inferiore: shortcut telefono/camera agli angoli + hint "All apps"
  /// centrato allo stesso livello. Lo swipe-su verso "All apps" è una gesture
  /// FISSA del launcher (non configurabile, a differenza di sx/dx rese come
  /// frecce laterali — vedi [_buildSideArrow]); l'hint resta sempre presente e
  /// tappabile (stessa azione dello swipe, utile dove la gesture di sistema
  /// interferisce). Lo Stack centra "All apps" tra le due icone senza overlap
  /// dei tap: hint stretto al centro, icone ai bordi.
  Widget _buildBottomBar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const LauncherShortcutButtons(),
        _SwipeHint(
          icon: Icons.keyboard_arrow_up,
          label: 'All apps',
          onTap: _openAllApps,
        ),
      ],
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
    // Solo swipe verso l'alto (velocity negativa) → "All apps" (gesture fissa,
    // non configurabile). Lo swipe verso il basso non è mappato.
    if (v >= -_kSwipeVelocityThreshold) return;
    _openAllApps();
  }

  /// Lo swipe verso l'alto (dal basso) è una gesture FISSA del launcher: apre
  /// sempre il drawer "All apps". Non è configurabile (a differenza di sx/dx),
  /// così l'accesso a tutte le app resta un gesto core garantito.
  void _openAllApps() => context.push(KoruRoutes.launcherDrawer);

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

/// Icona top-left del launcher: numero di "schede aperte in background" +
/// apertura del gestore schede (le recents di sistema, via
/// AccessibilityService — vedi `openSystemRecents`). Il conteggio è
/// l'approssimazione tracciata da OpenAppsTracker (app in foreground dal
/// boot / ultimo reset). Stati:
/// - servizio accessibilità OFF → nascosta (GLOBAL_ACTION_RECENTS impossibile
///   e il blocco gesture non è comunque operativo);
/// - usage stats OFF → icona senza badge (conteggio non derivabile);
/// - strict BLOCK_RECENT_APPS → disabilitata (lo strict richiuderebbe la
///   schermata subito: niente flash-and-kick offerto dall'icona);
/// - count == 0 → icona visibile senza badge (resta il bottone recents).
/// Long-press: azzera il contatore (escape hatch dell'approssimazione, es.
/// dopo aver chiuso le schede una a una senza "Cancella tutto").
class _RecentsShortcut extends ConsumerWidget {
  const _RecentsShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(recentsIconCapabilityProvider).valueOrNull;
    if (capability == null || !capability.iconVisible) {
      // Slot della stessa altezza del "K": il layout non salta quando la
      // capability arriva o cambia.
      return const SizedBox(width: 40, height: 40);
    }
    final count = ref.watch(openAppsCountProvider).valueOrNull ?? 0;
    final enabled = capability.tapEnabled;
    final color = enabled ? KoruColors.primary : KoruColors.textSecondary;
    final showBadge = capability.badgeVisible && count > 0;

    return Material(
      color: KoruColors.primary.withAlpha(enabled ? 40 : 20),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: enabled ? () => _openRecents(context, ref) : null,
        onLongPress: enabled ? () => _resetCount(context, ref) : null,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_none, size: 18, color: color),
                if (showBadge) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRecents(BuildContext context, WidgetRef ref) async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    // openSystemRecents emette l'allow-token sul gate nativo prima di
    // GLOBAL_ACTION_RECENTS (altrimenti il blocco gesture la richiuderebbe).
    await blocking.openSystemRecents();
    // Dopo l'await il widget può essere stato smontato (es. HOME intent che
    // rimpiazza la route): usare ref oltre l'unmount lancia StateError.
    if (!context.mounted) return;
    // Al rientro il conteggio può essere cambiato (clear-all, app chiuse):
    // il resume del launcher lo rinfresca comunque, questo accorcia l'attesa.
    ref.invalidate(openAppsCountProvider);
  }

  Future<void> _resetCount(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref
        .read(platformChannelServiceProvider)
        .blocking
        .resetOpenAppsCount();
    // Mounted guard PRIMA di ri-usare ref (stessa ragione di _openRecents).
    if (!context.mounted) return;
    ref.invalidate(openAppsCountProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open apps counter reset'),
        duration: Duration(seconds: 2),
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
