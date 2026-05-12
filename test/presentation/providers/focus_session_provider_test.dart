import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/repositories/focus_session_repository.dart';
import 'package:koru/platform/service_event_channel.dart';
import 'package:koru/presentation/providers/focus_session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('focusSessionRepositoryProvider', () {
    test('builds a FocusSessionRepository bound to the db', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(focusSessionRepositoryProvider);
      expect(repo, isA<FocusSessionRepository>());
    });

    test('repo.recordCompletedSession writes to the DAO', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(focusSessionRepositoryProvider);
      await repo.recordCompletedSession(const Duration(minutes: 25));

      final lifetimeMs = await h.db.focusUsageEventsDao.getLifetimeFocusMs();
      expect(lifetimeMs, 25 * 60 * 1000);
    });
  });

  group('quickBlockTickProvider', () {
    test(
        'filters the events stream and yields only QuickBlockTickEvent',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final controller = StreamController<KoruServiceEvent>();
      when(() => h.events.events()).thenAnswer((_) => controller.stream);

      final emissions = <QuickBlockTickEvent>[];
      final sub = h
          .container
          .read(quickBlockTickProvider.stream)
          .listen(emissions.add);

      // Mischia eventi: solo i tick devono passare.
      controller.add(const ServiceStateEvent(running: true));
      controller.add(const QuickBlockTickEvent(
        remainingMs: 5000,
        totalMs: 60000,
        isPomodoroBreak: false,
        isActive: true,
        currentCycle: 1,
        totalCycles: 4,
      ));
      controller.add(const BlockingStateEvent(
        isBlocking: true,
        packageName: 'com.x',
        profileId: 1,
        profileTitle: 'P',
      ));
      controller.add(const QuickBlockTickEvent(
        remainingMs: 4000,
        totalMs: 60000,
        isPomodoroBreak: false,
        isActive: true,
        currentCycle: 1,
        totalCycles: 4,
      ));

      // Chiudi il controller e attendi che lo stream-provider drenati
      // tutti i microtask.
      await controller.close();
      // Tre micro-flush per essere sicuri: events → async* → output → listener.
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(emissions, hasLength(2));
      expect(emissions[0].remainingMs, 5000);
      expect(emissions[1].remainingMs, 4000);

      await sub.cancel();
    });

    test('empty event stream produces no tick emissions', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      // Stream vuoto NON const: si chiude subito ma è single-sub.
      when(() => h.events.events())
          .thenAnswer((_) => Stream<KoruServiceEvent>.empty());

      final emissions = <QuickBlockTickEvent>[];
      final sub = h
          .container
          .read(quickBlockTickProvider.stream)
          .listen(emissions.add);

      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(emissions, isEmpty);
      await sub.cancel();
    });
  });
}
