import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koru/domain/entities/achievement.dart';
import 'package:koru/presentation/providers/achievements_provider.dart';
import 'package:koru/presentation/screens/statistics/widgets/achievements_grid.dart';

import '../../_helpers/provider_test_utils.dart';

Widget _wrap(ProviderContainer container, Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
      GoRoute(
        path: '/stats/achievements',
        builder: (_, _) => const Scaffold(body: Text('AllAchievements')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('AchievementsGrid', () {
    testWidgets('smoke: renders the section title and "View all" button',
        (tester) async {
      final h = buildTestContainer(extra: [
        unlockedAchievementIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(const {}),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const AchievementsGrid()));
      await tester.pumpAndSettle();

      expect(find.text('Achievements'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'View all'), findsOneWidget);
    });

    testWidgets('renders the X/Y counter ("0/15" when none unlocked)',
        (tester) async {
      final h = buildTestContainer(extra: [
        unlockedAchievementIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(const {}),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const AchievementsGrid()));
      await tester.pumpAndSettle();

      // Catalog has 15 entries (see kAchievementCatalog).
      expect(find.text('0/${kAchievementCatalog.length}'), findsOneWidget);
    });

    testWidgets('shows the first 6 achievements as badges (grid preview)',
        (tester) async {
      final h = buildTestContainer(extra: [
        unlockedAchievementIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(const {}),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const AchievementsGrid()));
      await tester.pumpAndSettle();

      // Exactly 1 GridView.count.
      expect(find.byType(GridView), findsOneWidget);
      // 6 preview tiles → 6 icons (each badge has 1 Icon).
      // We use AtLeast because the parent could have other icons (it doesn't,
      // but safe), and we want resilience.
      expect(find.byType(Icon), findsNWidgets(6));
    });

    testWidgets('reflects unlocked set in the counter', (tester) async {
      final unlocked = <String>{'focus_first', 'focus_hour', 'streak_focus_7'};
      final h = buildTestContainer(extra: [
        unlockedAchievementIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(unlocked),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const AchievementsGrid()));
      await tester.pumpAndSettle();

      expect(find.text('3/${kAchievementCatalog.length}'), findsOneWidget);
    });

    testWidgets('tap on "View all" navigates to /stats/achievements',
        (tester) async {
      final h = buildTestContainer(extra: [
        unlockedAchievementIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(const {}),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const AchievementsGrid()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'View all'));
      await tester.pumpAndSettle();

      expect(find.text('AllAchievements'), findsOneWidget);
    });

    testWidgets(
        'unlocked achievements appear before locked ones in the preview',
        (tester) async {
      // Unlock an item that's late in the catalog: this forces re-sort.
      // 'setup_lockdown' è index 13 → senza sort apparirebbe oltre la 6,
      // ma il widget lo deve portare in cima.
      final unlocked = <String>{'setup_lockdown'};
      final h = buildTestContainer(extra: [
        unlockedAchievementIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(unlocked),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const AchievementsGrid()));
      await tester.pumpAndSettle();

      // The 'Lockdown' title should be visible in the preview area.
      expect(find.text('Lockdown'), findsOneWidget);
    });
  });
}
