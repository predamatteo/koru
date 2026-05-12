import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/favorites_provider.dart';
import 'package:koru/presentation/screens/home/widgets/favorites_list.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('FavoritesList', () {
    testWidgets('shows the empty hint when no favorites are configured',
        (tester) async {
      final h = buildTestContainer(extra: [
        favoriteAppsProvider.overrideWith((ref) => const []),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: FavoritesList()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Long-press an app in the drawer to add it here.'),
        findsOneWidget,
      );
      expect(find.byType(ReorderableListView), findsNothing);
    });

    testWidgets('renders one entry per favorite app and shows their labels',
        (tester) async {
      final favorites = [
        InstalledAppInfo(packageName: 'com.a', label: 'Alpha'),
        InstalledAppInfo(packageName: 'com.b', label: 'Beta'),
        InstalledAppInfo(packageName: 'com.c', label: 'Charlie'),
      ];

      final h = buildTestContainer(extra: [
        favoriteAppsProvider.overrideWith((ref) => favorites),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: FavoritesList(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('tapping a favorite invokes blocking.launchApp(packageName)',
        (tester) async {
      final favorites = [
        InstalledAppInfo(packageName: 'com.koru', label: 'Koru'),
      ];

      final h = buildTestContainer(extra: [
        favoriteAppsProvider.overrideWith((ref) => favorites),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: FavoritesList(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Koru'));
      await tester.pump();

      verify(() => h.blocking.launchApp('com.koru')).called(1);
    });

    testWidgets(
        'the favoritesController provider is wired to the DB (uses real db)',
        (tester) async {
      // Smoke test: leggere `favoritesControllerProvider` non deve crashare
      // quando il container ha tutto wired correttamente.
      final favorites = [
        InstalledAppInfo(packageName: 'com.x', label: 'X'),
      ];

      final h = buildTestContainer(extra: [
        favoriteAppsProvider.overrideWith((ref) => favorites),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: FavoritesList(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Il controller esiste e ha un AppDatabase reale (mockabile via h.db).
      final controller = h.container.read(favoritesControllerProvider);
      expect(controller, isNotNull);
    });
  });
}
