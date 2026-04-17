import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/all_apps/all_apps_screen.dart';
import '../../presentation/screens/focus/focus_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/launcher_shell/launcher_shell.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/profiles/profile_editor_screen.dart';
import '../../presentation/screens/profiles/profiles_list_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/statistics/statistics_screen.dart';

/// Route names accessibili da tutta l'app (evita hard-coded strings).
class KoruRoutes {
  const KoruRoutes._();

  static const String onboarding = '/onboarding';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: KoruRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: KoruRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
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
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
