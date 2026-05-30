import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/hive_keys.dart';
import '../di/providers.dart';
import '../../presentation/screens/all_apps/all_apps_screen.dart';
import '../../presentation/screens/focus/focus_screen.dart';
import '../../presentation/screens/focus/pomodoro_screen.dart';
import '../../presentation/screens/focus/quick_block_screen.dart';
import '../../presentation/screens/focus/whitelist_editor_screen.dart';
import '../../presentation/providers/focus_whitelist_provider.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/launcher/launcher_home_screen.dart';
import '../../presentation/screens/launcher/launcher_shortcut_picker_screen.dart';
import '../../presentation/screens/launcher/launcher_swipe_picker_screen.dart';
import '../../presentation/screens/mood/journal_screen.dart';
import '../../presentation/providers/launcher_shortcuts_provider.dart';
import '../../presentation/providers/launcher_swipe_actions_provider.dart';
import '../../presentation/screens/launcher_shell/launcher_shell.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/profiles/profile_editor_screen.dart';
import '../../presentation/screens/profiles/profiles_list_screen.dart';
import '../../presentation/screens/profiles/sub_screens/block_in_app_content_screen.dart';
import '../../presentation/screens/profiles/sub_screens/overlay_designer_screen.dart';
import '../../presentation/screens/profiles/sub_screens/set_blocked_apps_screen.dart';
import '../../presentation/screens/profiles/sub_screens/websites_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/sub_screens/about_screen.dart';
import '../../presentation/screens/settings/sub_screens/app_limits_screen.dart';
import '../../presentation/screens/settings/sub_screens/app_personalization_screen.dart';
import '../../presentation/screens/settings/sub_screens/backdoor_codes_screen.dart';
import '../../presentation/screens/settings/sub_screens/notification_filter_screen.dart';
import '../../presentation/screens/settings/sub_screens/font_screen.dart';
import '../../presentation/screens/settings/sub_screens/launcher_settings_screen.dart';
import '../../presentation/screens/settings/sub_screens/permissions_screen.dart';
import '../../presentation/screens/settings/sub_screens/strict_mode_screen.dart';
import '../../presentation/screens/statistics/achievements_screen.dart';
import '../../presentation/screens/statistics/statistics_screen.dart';

/// Route names accessibili da tutta l'app (evita hard-coded strings).
class KoruRoutes {
  const KoruRoutes._();

  static const String onboarding = '/onboarding';

  /// Launcher UI (clock + favoriti + drawer), FUORI dallo shell, senza bottom
  /// nav. Visibile solo quando Koru è lanciato via HOME intent (MainActivity
  /// imposta defaultRouteName a `/launcher` in quel caso).
  static const String launcher = '/launcher';
  static const String launcherDrawer = '/launcher/drawer';
  static const String launcherShortcuts = '/launcher/shortcut';
  static const String launcherSwipe = '/launcher/swipe';

  /// Tab Home dentro lo shell (dashboard).
  static const String home = '/home';
  static const String drawer = '/home/drawer';
  static const String profiles = '/profiles';
  static const String focus = '/focus';
  static const String stats = '/stats';
  static const String settings = '/settings';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Observer del navigator root: permette a [LauncherHomeScreen] di sapere
/// quando è la route in cima (RouteAware) e attivare l'override delle gesture
/// di sistema SOLO lì. Le sub-route del launcher (drawer/swipe/shortcut) e il
/// push di `/home` (tasto "K") vivono tutte sul navigator root, quindi i
/// callback didPushNext/didPopNext scattano correttamente quando il launcher
/// viene coperto o riscoperto.
final launcherRouteObserver = RouteObserver<PageRoute<dynamic>>();

final shellNavigatorHomeKey = GlobalKey<NavigatorState>();
final shellNavigatorProfilesKey = GlobalKey<NavigatorState>();
final shellNavigatorFocusKey = GlobalKey<NavigatorState>();
final shellNavigatorStatsKey = GlobalKey<NavigatorState>();
final shellNavigatorSettingsKey = GlobalKey<NavigatorState>();

/// Route iniziale dell'app: se Flutter riceve `defaultRouteName == '/launcher'`
/// (impostato da MainActivity.getInitialRoute quando l'app è stata lanciata
/// via HOME intent) partiamo dal launcher. Altrimenti partiamo dalla tab Home.
String _resolveInitialRoute() {
  final name = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (name == KoruRoutes.launcher) return KoruRoutes.launcher;
  return KoruRoutes.home;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final hive = ref.watch(hiveSettingsServiceProvider);
  final initialLocation = _resolveInitialRoute();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [launcherRouteObserver],
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final onboarded = hive.getBool(
        HiveKeys.onboardingBox,
        HiveKeys.isOnboardingPassed,
        defaultValue: false,
      );
      final loc = state.matchedLocation;
      if (!onboarded && loc != KoruRoutes.onboarding) {
        return KoruRoutes.onboarding;
      }
      if (onboarded && loc == KoruRoutes.onboarding) {
        return initialLocation;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: KoruRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Launcher mode: top-level, no bottom navigation.
      GoRoute(
        path: KoruRoutes.launcher,
        builder: (context, state) => const LauncherHomeScreen(),
        routes: [
          GoRoute(
            path: 'drawer',
            builder: (context, state) => AllAppsScreen(
              // `?focus=search` → apre il drawer con la ricerca già in focus
              // (azione swipe "Ricerca app"). Senza il param resta off.
              autofocusSearch:
                  state.uri.queryParameters['focus'] == 'search',
            ),
          ),
          GoRoute(
            path: 'shortcut',
            builder: (context, state) {
              final slot =
                  (state.uri.queryParameters['slot'] ?? 'left') == 'right'
                      ? LauncherShortcutSlot.right
                      : LauncherShortcutSlot.left;
              return LauncherShortcutPickerScreen(slot: slot);
            },
          ),
          GoRoute(
            path: 'swipe',
            builder: (context, state) {
              final dir = switch (state.uri.queryParameters['dir']) {
                'right' => LauncherSwipeDirection.right,
                // Lo swipe verso l'alto è fisso (nessun picker): il drawer di
                // configurazione gestisce solo gli swipe laterali. Fallback a
                // sinistra per qualsiasi valore non riconosciuto.
                _ => LauncherSwipeDirection.left,
              };
              return LauncherSwipePickerScreen(direction: dir);
            },
          ),
        ],
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            LauncherShell(navigationShell: navigationShell),
        // Lazy IndexedStack: al cold start solo la tab visibile viene
        // costruita, le altre restano `SizedBox.shrink` finché l'utente
        // non le tocca. Questo evita che HomeScreen + ProfilesListScreen +
        // FocusScreen + StatisticsScreen + SettingsScreen vengano
        // istanziate tutte insieme (l'IndexedStack di default builda tutti
        // i children in parallelo). Riduce drasticamente il numero di
        // provider FutureProvider/StreamProvider attivati al boot — in
        // particolare evita due chiamate `getUsageStats` (UsageStatsManager
        // native, ~hundreds of ms) di StatisticsScreen quando l'utente
        // parte sulla Home.
        //
        // Lo stato di navigazione di ogni branch resta preservato dopo la
        // prima visita: una volta che `_visited[i]` diventa true, il
        // Navigator del branch resta nel tree (anche quando l'utente passa
        // a un altro tab) — IndexedStack lo nasconde con Offstage senza
        // distruggerlo.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            _LazyShellContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: KoruRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'drawer',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AllAppsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorProfilesKey,
            routes: [
              GoRoute(
                path: KoruRoutes.profiles,
                builder: (context, state) => const ProfilesListScreen(),
                // Le route di editing profile escono dallo shell
                // (parentNavigatorKey=rootNavigatorKey) così la floating nav
                // bar non è visibile mentre si modifica un profilo.
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ProfileEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ProfileEditorScreen(
                      profileId: int.tryParse(state.pathParameters['id'] ?? ''),
                    ),
                    routes: [
                      GoRoute(
                        path: 'apps',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => SetBlockedAppsScreen(
                          profileId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'sections',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => BlockInAppContentScreen(
                          profileId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'websites',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => WebsitesScreen(
                          profileId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'overlay/:pkg',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => OverlayDesignerScreen(
                          profileId: int.parse(state.pathParameters['id']!),
                          packageName: state.pathParameters['pkg']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorFocusKey,
            routes: [
              GoRoute(
                path: KoruRoutes.focus,
                builder: (context, state) => const FocusScreen(),
                routes: [
                  GoRoute(
                    path: 'quick',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const QuickBlockScreen(),
                    routes: [
                      GoRoute(
                        path: 'whitelist',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            const WhitelistEditorScreen(mode: FocusMode.quickBlock),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'pomodoro',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const PomodoroScreen(),
                    routes: [
                      GoRoute(
                        path: 'whitelist',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            const WhitelistEditorScreen(mode: FocusMode.pomodoro),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorStatsKey,
            routes: [
              GoRoute(
                path: KoruRoutes.stats,
                builder: (context, state) => const StatisticsScreen(),
                routes: [
                  GoRoute(
                    path: 'achievements',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AchievementsScreen(),
                  ),
                  GoRoute(
                    path: 'journal',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const JournalScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: KoruRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'strict-mode',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const StrictModeScreen(),
                  ),
                  GoRoute(
                    path: 'backdoor',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const BackdoorCodesScreen(),
                  ),
                  GoRoute(
                    path: 'font',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const FontScreen(),
                  ),
                  GoRoute(
                    path: 'launcher',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const LauncherSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'app-limits',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AppLimitsScreen(),
                  ),
                  GoRoute(
                    path: 'app-personalization',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const AppPersonalizationScreen(),
                  ),
                  GoRoute(
                    path: 'notification-filter',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const NotificationFilterScreen(),
                  ),
                  GoRoute(
                    path: 'permissions',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const PermissionsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// IndexedStack che costruisce ogni branch solo alla prima visita.
///
/// Sostituisce il container default di `StatefulShellRoute.indexedStack` che
/// monta tutti i Navigator dei branch al primo build dello shell, causando
/// la costruzione contemporanea di HomeScreen + ProfilesListScreen +
/// FocusScreen + StatisticsScreen + SettingsScreen al cold start — e con
/// loro l'attivazione in parallelo di tutti i provider che quelle schermate
/// `ref.watch`, fra cui chiamate native onerose (UsageStats, PackageManager
/// scan + icon decode) della Stats tab anche quando l'utente entra in app
/// dalla Home.
///
/// Una volta visitato, un branch resta nel tree (IndexedStack lo nasconde
/// con Offstage), quindi lo stato di navigazione interno è preservato fra
/// tab switch.
class _LazyShellContainer extends StatefulWidget {
  const _LazyShellContainer({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<_LazyShellContainer> createState() => _LazyShellContainerState();
}

class _LazyShellContainerState extends State<_LazyShellContainer> {
  late final List<bool> _visited =
      List<bool>.filled(widget.children.length, false, growable: false);

  @override
  void initState() {
    super.initState();
    _visited[widget.currentIndex] = true;
  }

  @override
  void didUpdateWidget(covariant _LazyShellContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_visited[widget.currentIndex]) {
      _visited[widget.currentIndex] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.currentIndex,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited[i] ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
