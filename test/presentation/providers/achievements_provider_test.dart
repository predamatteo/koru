import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/achievement.dart';
import 'package:koru/presentation/providers/achievements_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('streaksRepositoryProvider / achievementsRepositoryProvider', () {
    test('build wired instances from db (single-shot, identity)', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final streaks1 = h.container.read(streaksRepositoryProvider);
      final streaks2 = h.container.read(streaksRepositoryProvider);
      expect(identical(streaks1, streaks2), isTrue);

      final ach1 = h.container.read(achievementsRepositoryProvider);
      final ach2 = h.container.read(achievementsRepositoryProvider);
      expect(identical(ach1, ach2), isTrue);
    });
  });

  group('unlockedAchievementIdsProvider', () {
    test('emits empty set when no achievements unlocked', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final ids =
          await h.container.read(unlockedAchievementIdsProvider.stream).first;
      expect(ids, isEmpty);
    });

    test('emits unlocked ids after repo.unlock', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(achievementsRepositoryProvider);
      await repo.unlock('focus_first');
      await repo.unlock('focus_hour');

      final ids =
          await h.container.read(unlockedAchievementIdsProvider.stream).first;
      expect(ids, {'focus_first', 'focus_hour'});
    });
  });

  group('NewUnlocksController', () {
    test('emit() pushes onto the broadcast stream', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final controller = h.container.read(newUnlocksControllerProvider);
      const a = Achievement(
        id: 'focus_first',
        title: 'First focus',
        description: 'desc',
        icon: Icons.self_improvement_outlined,
        category: AchievementCategory.focus,
        target: 1,
      );

      // Sottoscrivi prima di emettere — broadcast non bufferizza.
      final future = controller.stream.first;
      controller.emit(a);
      final received = await future;
      expect(received.id, 'focus_first');
    });

    test('multiple subscribers receive the same emit', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final controller = h.container.read(newUnlocksControllerProvider);
      final f1 = controller.stream.first;
      final f2 = controller.stream.first;

      const a = Achievement(
        id: 'focus_hour',
        title: 'Focused hour',
        description: 'd',
        icon: Icons.hourglass_full_outlined,
        category: AchievementCategory.focus,
        target: 60,
      );
      controller.emit(a);

      final r1 = await f1;
      final r2 = await f2;
      expect(r1.id, 'focus_hour');
      expect(r2.id, 'focus_hour');
    });

    test('provider returns the same controller across reads', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final c1 = h.container.read(newUnlocksControllerProvider);
      final c2 = h.container.read(newUnlocksControllerProvider);
      expect(identical(c1, c2), isTrue);
    });
  });

  group('newAchievementUnlocksStreamProvider', () {
    test('forwards events from NewUnlocksController.emit', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // Iscrivi al provider stream PRIMA di emettere.
      final future = h
          .container
          .read(newAchievementUnlocksStreamProvider.stream)
          .first;

      const a = Achievement(
        id: 'streak_focus_7',
        title: 'Weekling',
        description: 'd',
        icon: Icons.local_fire_department_outlined,
        category: AchievementCategory.consistency,
        target: 7,
      );
      h.container.read(newUnlocksControllerProvider).emit(a);

      final ev = await future;
      expect(ev.id, 'streak_focus_7');
    });
  });

  // NOTE: AchievementEvaluationNotifier.trigger() e buildAchievementStats
  // dipendono da molti channel + DB query custom (customSelect). Coperti
  // dai test della repo + use case `evaluate_achievements_test.dart`;
  // qui ci limitiamo al wiring di NewUnlocksController.
}
