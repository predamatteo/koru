import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/router/app_router.dart';
import 'package:koru/domain/entities/achievement.dart';
import 'package:koru/presentation/providers/achievements_provider.dart';
import 'package:koru/presentation/widgets/achievement_unlock_listener.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('AchievementUnlockListener', () {
    testWidgets('smoke: renders the provided child', (tester) async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(
              body: AchievementUnlockListener(
                child: Text('child-content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('child-content'), findsOneWidget);
    });

    testWidgets(
        'side-effect: emitting a new unlock shows the SnackBar with title',
        (tester) async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // Listener stesso usa `rootNavigatorKey.currentContext`; per essere
      // sicuri che ScaffoldMessenger sia trovato dal context, montiamo
      // l'intero tree con `MaterialApp(navigatorKey: rootNavigatorKey)`.
      // Senza rootNavigatorKey impostato, lo snackbar non comparirebbe.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(
              body: AchievementUnlockListener(
                child: Text('app-body'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Emit un achievement via il controller del provider.
      final controller = h.container.read(newUnlocksControllerProvider);
      controller.emit(const Achievement(
        id: 'focus_first',
        title: 'First focus',
        description: 'Complete your first focus session.',
        iconKey: 'self_improvement_outlined',
        category: AchievementCategory.focus,
        target: 1,
      ));

      // Drena lo stream: il listener si attiva solo se il provider è "watched"
      // → forza il read.
      // ignore: unused_local_variable
      final _ = h.container.read(newAchievementUnlocksStreamProvider);
      // Microtask + frame per dare tempo al broadcast stream di propagarsi.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Lo snackbar deve mostrare il titolo dell'achievement.
      expect(find.text('First focus'), findsOneWidget);
      expect(find.text('Achievement unlocked'), findsOneWidget);
    });

    testWidgets('no SnackBar appears when the stream emits nothing',
        (tester) async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(
              body: AchievementUnlockListener(
                child: Text('idle'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Achievement unlocked'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
