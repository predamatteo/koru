import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/diagnostics/black_box.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/koru_type.dart';
import '../../../core/theme/launcher_motion.dart';
import '../../../core/theme/launcher_phase.dart';
import '../../../platform/permission_channel.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/launcher_shortcuts_provider.dart';
import '../../providers/launcher_swipe_actions_provider.dart';
import '../../providers/open_apps_count_provider.dart';
import '../../widgets/koru_spiral.dart';
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

/// Schermata launcher — **"Inchiostro e ore"**.
///
/// Un launcher che non si muove mai da solo, e che non è mai due volte lo
/// stesso: palette, spaziatura e peso della tipografia sono derivati dall'ora
/// ([LauncherPhase]), e il movimento esiste solo sotto il dito
/// ([LauncherMotion]).
///
/// Tre regole, in ordine di importanza:
///
/// 1. **Fermo.** A dito alzato il launcher non disegna un frame: nessun loop,
///    nessun `Timer.periodic`. Gli unici risvegli sono il confine del minuto
///    (l'orologio, che comunque cambia) e il confine di fascia oraria — due
///    volte al giorno.
/// 2. **In movimento.** Il contenuto si solleva e arretra, la spirale koru si
///    srotola sotto il dito, tutto rientra con la curva di [LauncherMotion].
/// 3. **Il tempo è materia.** Due fasce, gli stessi token di Koru: cambia la
///    luce, non la tinta.
///
/// Composizione asimmetrica: orologio in alto a sinistra, preferiti ancorati
/// al pollice, mai il centrato-verticale di tutti. `TEL` e `CAM` sono parole,
/// non icone — il dogma solo-testo vale anche per la UI del launcher.
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
    with WidgetsBindingObserver, RouteAware, SingleTickerProviderStateMixin {
  ModalRoute<dynamic>? _subscribedRoute;

  /// Canale permessi cacheato in [initState]: il path di teardown
  /// (`dispose` → `_setLauncherActive(false)`) NON può usare `ref` —
  /// Riverpod lancia StateError dopo l'unmount (context.mounted è già
  /// false durante dispose), il che lasciava l'esclusione gesture e lo
  /// shield recents nativi accesi e saltava removeObserver/super.dispose.
  late final PermissionChannel _permission;

  /// Srotolamento: `0` = home ferma, `1` = drawer aperto. Guidato dal dito
  /// durante il drag e portato a destinazione con [LauncherMotion.settle] al
  /// rilascio. È un [AnimationController] e non uno stato in `setState` per
  /// due ragioni: (a) fermo non consuma nulla — nessun ticker in corsa, (b) i
  /// frame del drag ridisegnano solo i due [AnimatedBuilder] che lo ascoltano,
  /// non l'intero albero con dentro la lista preferiti.
  late final AnimationController _unfurl;

  /// Trascinamento orizzontale accumulato (px, segno = verso del dito).
  /// [ValueNotifier] e non `setState` per la stessa ragione: accende le
  /// hairline laterali senza ricostruire la schermata a ogni frame.
  final ValueNotifier<double> _hairDrag = ValueNotifier<double>(0);

  bool _draggingUp = false;
  double _dragStartY = 0;

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
    _unfurl = AnimationController(
      vsync: this,
      duration: LauncherMotion.settleDuration,
    );
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
    _unfurl.dispose();
    _hairDrag.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── RouteAware: gli override "da launcher" vivono SOLO quando è in cima ──
  // Due override sono scoping-sensibili e vanno spenti quando il launcher è
  // coperto: (1) l'esclusione gesture di sistema e (2) la nav bar nascosta. Il
  // tasto spirale fa push di /home SOPRA il launcher (che resta montato sotto):
  // senza scoping l'esclusione bloccherebbe back/home di sistema e la nav bar
  // resterebbe nascosta dentro l'app. didPushNext (coperto) → off; didPopNext /
  // didPush (riscoperto o primo mount) → on.
  @override
  void didPush() => _setLauncherActive(true);

  @override
  void didPopNext() {
    _setLauncherActive(true);
    // Rientro elastico della home quando il drawer (o qualsiasi altra route
    // sovrapposta) si chiude. Ancorato qui e non a un `await context.push`
    // così copre anche il back di sistema e il pop programmatico.
    _settleHome();
  }

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
      _settleHome();
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

  // ─── Srotolamento ────────────────────────────────────────────────────────

  void _settleHome() {
    if (_unfurl.value == 0) return;
    _unfurl.animateTo(
      0,
      duration: LauncherMotion.settleDuration,
      curve: LauncherMotion.settle,
    );
  }

  void _onVerticalDragStart(DragStartDetails d) {
    if (_unfurl.value > 0.5) return;
    _dragStartY = d.globalPosition.dy;
    _draggingUp = true;
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (!_draggingUp) return;
    // Solo verso l'alto: un drag verso il basso lascia lo srotolamento a 0.
    final travelled = _dragStartY - d.globalPosition.dy;
    _unfurl.value =
        (travelled / LauncherMotion.unfurlDistance).clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (!_draggingUp) return;
    _draggingUp = false;
    // Un flick corto ma deciso apre comunque: la velocità vale quanto la
    // distanza (è il comportamento che il launcher aveva già prima del drag
    // continuo, e che le dita abituate si aspettano).
    final velocity = d.primaryVelocity ?? 0;
    if (_unfurl.value > LauncherMotion.unfurlCommit ||
        velocity <= -_kSwipeVelocityThreshold) {
      _openAllApps();
    } else {
      _settleHome();
    }
  }

  void _onVerticalDragCancel() {
    if (!_draggingUp) return;
    _draggingUp = false;
    _settleHome();
  }

  // ─── Swipe laterali ──────────────────────────────────────────────────────

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    _hairDrag.value += d.delta.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    _hairDrag.value = 0;
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < _kSwipeVelocityThreshold) return;
    // primaryVelocity > 0 = movimento verso destra.
    _handleSwipe(
      v > 0 ? LauncherSwipeDirection.right : LauncherSwipeDirection.left,
    );
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

    return LauncherPhaseBuilder(
      builder: (context, phase) => Scaffold(
        backgroundColor: phase.background,
        body: SafeArea(
          // GestureDetector a livello schermo per le swipe personalizzabili.
          // `opaque` così riceve i drag anche sulle zone "vuote" del layout.
          // L'arena di Flutter fa da sola il lock d'asse fra i due
          // riconoscitori: il primo movimento decide se è uno swipe laterale
          // (hairline + azione configurabile) o lo srotolamento verticale.
          // Quando la lista preferiti ha contenuto scrollabile è LEI a vincere
          // l'arena verticale e a scrollare; lì l'apertura avviene tirando
          // OLTRE il fondo (overscroll-to-open, vedi [_onFavoritesScroll]).
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: () => _hairDrag.value = 0,
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onVerticalDragCancel: _onVerticalDragCancel,
            child: AnimatedBuilder(
              animation: _unfurl,
              builder: (context, child) => _recede(_unfurl.value, child!),
              // `child` è costruito una volta sola e riusato a ogni frame del
              // drag: solo la trasformazione viene ricalcolata.
              child: Stack(
                children: [
                  _buildContent(phase),
                  // Sopra il contenuto, non sotto: la zona tappabile del
                  // filetto (20px, dentro il margine di 24px delle parole)
                  // dev'essere raggiungibile. Copre molto meno dei due slot
                  // freccia da 44px a tutta altezza che c'erano prima.
                  _EdgeHairline(
                    phase: phase,
                    drag: _hairDrag,
                    direction: LauncherSwipeDirection.right,
                    action: _actionFor(LauncherSwipeDirection.right),
                    onTap: () => _handleSwipe(LauncherSwipeDirection.right),
                  ),
                  _EdgeHairline(
                    phase: phase,
                    drag: _hairDrag,
                    direction: LauncherSwipeDirection.left,
                    action: _actionFor(LauncherSwipeDirection.left),
                    onTap: () => _handleSwipe(LauncherSwipeDirection.left),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// La home arretra mentre il drawer sale: si solleva di
  /// [LauncherMotion.homeLift], rimpicciolisce e sbiadisce. L'origine della
  /// scala è al 20% dell'altezza (sotto l'orologio) e non al centro, così a
  /// muoversi di più è il bordo inferiore — dove sta il dito.
  Widget _recede(double p, Widget child) {
    if (p == 0) return child;
    const origin = Alignment(0, -0.6);
    return Opacity(
      // clamp difensivo: la curva di rientro scavalca leggermente la
      // destinazione, e `Opacity` asserisce su valori fuori da [0, 1].
      opacity: (1 - LauncherMotion.homeFade * p).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -LauncherMotion.homeLift * p),
        child: Transform.scale(
          scale: 1 - LauncherMotion.homeScale * p,
          alignment: origin,
          child: child,
        ),
      ),
    );
  }

  Widget _buildContent(LauncherPhase phase) {
    return Column(
      children: [
        // Riga alta: schede aperte a sinistra, spirale koru a destra.
        SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RecentsShortcut(phase: phase),
                _KoruMark(
                  phase: phase,
                  onTap: () => context.push(KoruRoutes.home),
                ),
              ],
            ),
          ),
        ),
        // Le ore, in alto a sinistra. Non centrate: è la prima asimmetria.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircleClockWidget(phase: phase),
          ),
        ),
        // I preferiti: ancorati al fondo, sotto il pollice.
        Expanded(child: _buildFavorites(phase)),
        _buildBottomBar(phase),
      ],
    );
  }

  /// Lista favoriti con bordi superiore/inferiore sfumati: quando la lista
  /// scrolla (molti preferiti) il primo/ultimo item sfuma invece di tagliarsi
  /// netto contro le righe adiacenti. Il fade è applicato qui (call-site del
  /// launcher) e non dentro [FavoritesList], così non impatta gli altri usi.
  /// Il [NotificationListener] aggiunge l'overscroll-to-open (vedi
  /// [_onFavoritesScroll]) senza toccare scroll/reorder della lista.
  Widget _buildFavorites(LauncherPhase phase) {
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
        child: FavoritesList(phase: phase),
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

  /// Barra inferiore: `TEL` e `CAM` agli angoli, la maniglia koru al centro.
  ///
  /// La spirale non è un logo: è l'affordance. A riposo è arrotolata al 45%,
  /// e si srotola man mano che il dito tira verso l'alto — il gesto e il segno
  /// sono la stessa cosa. Resta tappabile: dove la gesture di sistema
  /// interferisce, un tap apre comunque il drawer.
  Widget _buildBottomBar(LauncherPhase phase) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LauncherShortcutWord(
              slot: LauncherShortcutSlot.left,
              label: 'TEL',
              semanticLabel: 'Phone',
              phase: phase,
            ),
            _AllAppsHandle(phase: phase, unfurl: _unfurl, onTap: _openAllApps),
            LauncherShortcutWord(
              slot: LauncherShortcutSlot.right,
              label: 'CAM',
              semanticLabel: 'Camera',
              phase: phase,
            ),
          ],
        ),
      ),
    );
  }

  /// Lo swipe verso l'alto (dal basso) è una gesture FISSA del launcher: apre
  /// sempre il drawer "All apps". Non è configurabile (a differenza di sx/dx),
  /// così l'accesso a tutte le app resta un gesto core garantito.
  void _openAllApps() => _pushDrawer(KoruRoutes.launcherDrawer);

  /// Porta lo srotolamento a fondo corsa e apre il drawer, che sale con la
  /// stessa curva (vedi la transizione della route in `app_router.dart`). Il
  /// rientro della home è gestito da [didPopNext].
  void _pushDrawer(String location) {
    _unfurl.animateTo(
      1,
      duration: LauncherMotion.settleDuration,
      curve: LauncherMotion.settle,
    );
    context.push(location);
  }

  LauncherSwipeAction _actionFor(LauncherSwipeDirection dir) =>
      ref.watch(launcherSwipeActionsProvider)[dir] ?? LauncherSwipeAction.none;

  void _handleSwipe(LauncherSwipeDirection dir) {
    final action =
        ref.read(launcherSwipeActionsProvider)[dir] ?? LauncherSwipeAction.none;
    switch (action.type) {
      case LauncherSwipeActionType.none:
        return;
      case LauncherSwipeActionType.allApps:
        _pushDrawer(KoruRoutes.launcherDrawer);
      case LauncherSwipeActionType.appSearch:
        _pushDrawer('${KoruRoutes.launcherDrawer}?focus=search');
      case LauncherSwipeActionType.openApp:
        final pkg = action.packageName;
        if (pkg != null && pkg.isNotEmpty) {
          ref.read(platformChannelServiceProvider).blocking.launchApp(pkg);
        }
    }
  }
}

/// Filetto da 1px sul bordo laterale: l'indicatore degli swipe configurabili
/// sx/dx, al posto dei due chevron Material.
///
/// A riposo è una hairline in `--hair`, praticamente muta. Durante un drag
/// orizzontale il lato *verso cui va il dito* si accende in accento e si
/// allunga proporzionalmente alla corsa: l'unica animazione laterale che
/// esiste, e solo mentre il dito è giù.
///
/// La zona tappabile è larga 20px (dentro il margine di 24px della
/// composizione, così non ruba tap alle parole dei preferiti) e replica
/// l'azione dello swipe: è l'escape hatch dove la gesture di sistema
/// interferisce, che prima davano le frecce. Se la direzione non ha un'azione
/// assegnata il filetto resta spento e non tappabile — non promette nulla.
class _EdgeHairline extends StatelessWidget {
  const _EdgeHairline({
    required this.phase,
    required this.drag,
    required this.direction,
    required this.action,
    required this.onTap,
  });

  final LauncherPhase phase;
  final ValueListenable<double> drag;
  final LauncherSwipeDirection direction;
  final LauncherSwipeAction action;
  final VoidCallback onTap;

  /// Lo swipe-RIGHT (dito sx→dx) parte dal bordo SINISTRO, e viceversa: il
  /// filetto che si accende è quello da cui il gesto nasce.
  bool get _onLeftEdge => direction == LauncherSwipeDirection.right;

  @override
  Widget build(BuildContext context) {
    if (action.type == LauncherSwipeActionType.none) {
      return const SizedBox.shrink();
    }
    return Align(
      // 46% dell'altezza, dentro la fascia dei preferiti.
      alignment: Alignment(_onLeftEdge ? -1 : 1, -0.08),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 20,
          height: LauncherMotion.hairlineHeight + LauncherMotion.hairlineStretch,
          child: Align(
            alignment: _onLeftEdge ? Alignment.centerLeft : Alignment.centerRight,
            child: ValueListenableBuilder<double>(
              valueListenable: drag,
              builder: (context, dx, _) {
                final towardsThisEdge = _onLeftEdge ? dx > 0 : dx < 0;
                final lit = towardsThisEdge
                    ? math.min(1.0, dx.abs() / LauncherMotion.hairlineFullLit)
                    : 0.0;
                return Container(
                  width: 1,
                  height: LauncherMotion.hairlineHeight +
                      LauncherMotion.hairlineStretch * lit,
                  color: towardsThisEdge ? phase.accent : phase.hair,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// La maniglia "tutte le app": spirale koru che si srotola col dito, più
/// l'etichetta che si accende man mano.
class _AllAppsHandle extends StatelessWidget {
  const _AllAppsHandle({
    required this.phase,
    required this.unfurl,
    required this.onTap,
  });

  final LauncherPhase phase;
  final Animation<double> unfurl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'All apps',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
          child: AnimatedBuilder(
            animation: unfurl,
            builder: (context, _) {
              final p = unfurl.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KoruSpiral(
                    size: 36,
                    color: phase.ink2,
                    strokeWidth: 4.6,
                    progress: KoruSpiral.unfurl(p),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'ALL APPS',
                    style: KoruType.mono(
                      size: 9,
                      color: phase.accent,
                      trackEm: 0.24,
                      opacity: (0.32 + 0.68 * p).clamp(0.0, 1.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Scorciatoia in alto a sinistra: numero di "schede aperte in background" +
/// apertura del gestore schede (le recents di sistema, via
/// AccessibilityService — vedi `openSystemRecents`). Il conteggio è
/// l'approssimazione tracciata da OpenAppsTracker (app in foreground dal
/// boot / ultimo reset). Un quadratino di 9px in hairline al posto di
/// `Icons.filter_none`, e il conteggio a due cifre in mono: `04 OPEN`.
///
/// Stati:
/// - servizio accessibilità OFF → nascosta (GLOBAL_ACTION_RECENTS impossibile
///   e il blocco gesture non è comunque operativo);
/// - usage stats OFF → etichetta senza conteggio (non derivabile);
/// - strict BLOCK_RECENT_APPS → attenuata e non tappabile (lo strict
///   richiuderebbe la schermata subito: niente flash-and-kick offerto);
/// - count == 0 → etichetta senza conteggio (resta il bottone recents).
///
/// Long-press: azzera il contatore (escape hatch dell'approssimazione, es.
/// dopo aver chiuso le schede una a una senza "Cancella tutto").
class _RecentsShortcut extends ConsumerWidget {
  const _RecentsShortcut({required this.phase});

  final LauncherPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(recentsIconCapabilityProvider).valueOrNull;
    if (capability == null || !capability.iconVisible) {
      // Slot della stessa altezza della spirale: il layout non salta quando la
      // capability arriva o cambia.
      return const SizedBox(width: 40, height: 40);
    }
    final count = ref.watch(openAppsCountProvider).valueOrNull ?? 0;
    final enabled = capability.tapEnabled;
    final showBadge = capability.badgeVisible && count > 0;
    final color = enabled
        ? phase.ink2
        : phase.ink2.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: enabled ? () => _openRecents(context, ref) : null,
      onLongPress: enabled ? () => _resetCount(context, ref) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(border: Border.all(color: color)),
            ),
            const SizedBox(width: 8),
            Text(
              showBadge ? '${'$count'.padLeft(2, '0')} OPEN' : 'OPEN',
              style: KoruType.mono(
                size: 10,
                color: color,
                trackEm: phase.trackEm,
              ),
            ),
          ],
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

/// Il marchio Koru in alto a destra: la spirale, srotolata, in accento.
/// Tap → dashboard (`/home`). Sostituisce il cerchio con la lettera "K".
class _KoruMark extends StatelessWidget {
  const _KoruMark({required this.phase, required this.onTap});

  final LauncherPhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Koru dashboard',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: KoruSpiral(size: 26, color: phase.accent),
          ),
        ),
      ),
    );
  }
}
