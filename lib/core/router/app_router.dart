import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/hive_keys.dart';
import '../di/providers.dart';
import '../../presentation/screens/all_apps/all_apps_screen.dart';
import '../../presentation/screens/focus/focus_screen.dart';
import '../../presentation/screens/focus/pomodoro_screen.dart';
import '../../presentation/screens/focus/quick_block_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/launcher/launcher_home_screen.dart';
import '../../presentation/screens/launcher_shell/launcher_shell.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/profiles/profile_editor_screen.dart';
import '../../presentation/screens/profiles/profiles_list_screen.dart';
import '../../presentation/screens/profiles/sub_screens/block_in_app_content_screen.dart';
import '../../presentation/screens/profiles/sub_screens/overlay_designer_screen.dart';
import '../../presentation/screens/profiles/sub_screens/set_blocked_apps_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/sub_screens/about_screen.dart';
import '../../presentation/screens/settings/sub_screens/backdoor_codes_screen.dart';
import '../../presentation/screens/settings/sub_screens/font_screen.dart';
import '../../presentation/screens/settings/sub_screens/launcher_settings_screen.dart';
import '../../presentation/screens/settings/sub_screens/strict_mode_screen.dart';
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

  /// Tab Home dentro lo shell (dashboard).
  static const String home = '/home';
  static const String drawer = '/home/drawer';
  static const String profiles = '/profiles';
  static const String focus = '/focus';
  static const String stats = '/stats';
  static const String settings = '/settings';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
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
            builder: (context, state) => const AllAppsScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            LauncherShell(navigationShell: navigationShell),
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
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ProfileEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ProfileEditorScreen(
                      profileId: int.tryParse(state.pathParameters['id'] ?? ''),
                    ),
                    routes: [
                      GoRoute(
                        path: 'apps',
                        builder: (context, state) => SetBlockedAppsScreen(
                          profileId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'sections',
                        builder: (context, state) => BlockInAppContentScreen(
                          profileId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'overlay/:pkg',
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
                    builder: (context, state) => const QuickBlockScreen(),
                  ),
                  GoRoute(
                    path: 'pomodoro',
                    builder: (context, state) => const PomodoroScreen(),
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
                    builder: (context, state) => const StrictModeScreen(),
                  ),
                  GoRoute(
                    path: 'backdoor',
                    builder: (context, state) => const BackdoorCodesScreen(),
                  ),
                  GoRoute(
                    path: 'font',
                    builder: (context, state) => const FontScreen(),
                  ),
                  GoRoute(
                    path: 'launcher',
                    builder: (context, state) => const LauncherSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
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
