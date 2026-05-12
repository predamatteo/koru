import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/streak.dart';
import 'package:koru/presentation/providers/achievements_provider.dart';
import 'package:koru/presentation/screens/statistics/widgets/streaks_row.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('StreaksRow', () {
    testWidgets('smoke: renders the three streak chips with default labels',
        (tester) async {
      final h = buildTestContainer(extra: [
        for (final id in StreakId.values)
          streakSnapshotProvider(id).overrideWith(
            (ref) => Stream<StreakSnapshot>.value(StreakSnapshot.empty(id)),
          ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: StreaksRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Mindful'), findsOneWidget);
      expect(find.text('Clean'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('🌿'), findsOneWidget);
      expect(find.text('✨'), findsOneWidget);
    });

    testWidgets('all three streaks render "0" when empty', (tester) async {
      final h = buildTestContainer(extra: [
        for (final id in StreakId.values)
          streakSnapshotProvider(id).overrideWith(
            (ref) => Stream<StreakSnapshot>.value(StreakSnapshot.empty(id)),
          ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: StreaksRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3 chip × testo "0".
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('shows the current count when streak is active (today incr.)',
        (tester) async {
      final now = DateTime.now();
      final today = dayKeyFor(now);

      final h = buildTestContainer(extra: [
        streakSnapshotProvider(StreakId.focus).overrideWith(
          (ref) => Stream<StreakSnapshot>.value(StreakSnapshot(
            id: StreakId.focus,
            currentCount: 5,
            longest: 12,
            lastIncrementedDay: today,
          )),
        ),
        streakSnapshotProvider(StreakId.mindful).overrideWith(
          (ref) => Stream<StreakSnapshot>.value(
              StreakSnapshot.empty(StreakId.mindful)),
        ),
        streakSnapshotProvider(StreakId.clean).overrideWith(
          (ref) => Stream<StreakSnapshot>.value(
              StreakSnapshot.empty(StreakId.clean)),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: StreaksRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      // longest > 0 → label "best 12".
      expect(find.text('best 12'), findsOneWidget);
    });

    testWidgets('renders three Expanded chips (layout sanity check)',
        (tester) async {
      final h = buildTestContainer(extra: [
        for (final id in StreakId.values)
          streakSnapshotProvider(id).overrideWith(
            (ref) => Stream<StreakSnapshot>.value(StreakSnapshot.empty(id)),
          ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: StreaksRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3 chips wrapped in Expanded (più gli Expanded interni di Row se any).
      expect(find.byType(Expanded), findsAtLeastNWidgets(3));
    });
  });
}
