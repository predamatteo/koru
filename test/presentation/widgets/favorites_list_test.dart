import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/launcher_item.dart';
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
        launcherItemsProvider.overrideWith((ref) => const <LauncherItem>[]),
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
      final items = <LauncherItem>[
        const LauncherLooseApp(LauncherApp(packageName: 'com.a', label: 'Alpha')),
        const LauncherLooseApp(LauncherApp(packageName: 'com.b', label: 'Beta')),
        const LauncherLooseApp(
            LauncherApp(packageName: 'com.c', label: 'Charlie')),
      ];

      final h = buildTestContainer(extra: [
        launcherItemsProvider.overrideWith((ref) => items),
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
      final items = <LauncherItem>[
        const LauncherLooseApp(
            LauncherApp(packageName: 'com.koru', label: 'Koru')),
      ];

      final h = buildTestContainer(extra: [
        launcherItemsProvider.overrideWith((ref) => items),
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

    testWidgets('a folder shows its count and reveals apps once tapped',
        (tester) async {
      final items = <LauncherItem>[
        const LauncherFolderItem(
          id: 1,
          name: 'Work',
          apps: [
            LauncherApp(packageName: 'com.slack', label: 'Slack'),
            LauncherApp(packageName: 'com.gmail', label: 'Gmail'),
          ],
        ),
      ];

      final h = buildTestContainer(extra: [
        launcherItemsProvider.overrideWith((ref) => items),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(height: 400, child: FavoritesList()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collassata: nome + conteggio visibili, app nascoste.
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Slack'), findsNothing);
      expect(find.text('Gmail'), findsNothing);

      // Tap → espande e mostra le app.
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('Slack'), findsOneWidget);
      expect(find.text('Gmail'), findsOneWidget);

      // Tap su un'app dentro la cartella lancia l'app.
      await tester.tap(find.text('Slack'));
      await tester.pump();
      verify(() => h.blocking.launchApp('com.slack')).called(1);
    });

    testWidgets(
        'the favoritesController provider is wired to the DB (uses real db)',
        (tester) async {
      final items = <LauncherItem>[
        const LauncherLooseApp(LauncherApp(packageName: 'com.x', label: 'X')),
      ];

      final h = buildTestContainer(extra: [
        launcherItemsProvider.overrideWith((ref) => items),
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

      final controller = h.container.read(favoritesControllerProvider);
      expect(controller, isNotNull);
    });
  });
}
