import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/platform/service_event_channel.dart';
import 'package:koru/platform/strict_mode_channel.dart';
import 'package:koru/presentation/providers/open_apps_count_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('openAppsCountProvider', () {
    test('ritorna il conteggio dal canale nativo', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.events.events())
          .thenAnswer((_) => const Stream<KoruServiceEvent>.empty());
      when(() => h.blocking.getOpenAppsCount()).thenAnswer(
          (_) async => const OpenAppsCountSnapshot(count: 5, seq: 1));

      final count = await h.container.read(openAppsCountProvider.future);

      expect(count, 5);
      verify(() => h.blocking.getOpenAppsCount()).called(1);
    });

    test('push nativo OpenAppsCountEvent aggiorna il badge senza refetch',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      final events = StreamController<KoruServiceEvent>.broadcast();
      addTearDown(events.close);
      when(() => h.events.events()).thenAnswer((_) => events.stream);
      when(() => h.blocking.getOpenAppsCount()).thenAnswer(
          (_) async => const OpenAppsCountSnapshot(count: 2, seq: 1));
      keepProviderAlive(h.container, openAppsCountProvider);

      expect(await h.container.read(openAppsCountProvider.future), 2);

      // Il sync nativo (card reali / reset) pusha il nuovo valore: il
      // provider lo applica direttamente, senza un secondo getOpenAppsCount.
      events.add(const OpenAppsCountEvent(count: 0, seq: 2));
      await Future<void>.delayed(Duration.zero);

      expect(h.container.read(openAppsCountProvider).valueOrNull, 0);
      verify(() => h.blocking.getOpenAppsCount()).called(1);
    });

    test(
        'stale-while-revalidate: durante un invalidate il valore precedente '
        'resta visibile via valueOrNull (regressione pattern unwrapPrevious)',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.events.events())
          .thenAnswer((_) => const Stream<KoruServiceEvent>.empty());
      // Primo fetch: risponde subito 3. Secondo fetch (post-invalidate):
      // resta in volo finché non completiamo manualmente.
      final second = Completer<OpenAppsCountSnapshot>();
      var callCount = 0;
      when(() => h.blocking.getOpenAppsCount()).thenAnswer((_) {
        callCount++;
        return callCount == 1
            ? Future.value(const OpenAppsCountSnapshot(count: 3, seq: 1))
            : second.future;
      });
      keepProviderAlive(h.container, openAppsCountProvider);

      await h.container.read(openAppsCountProvider.future);
      expect(h.container.read(openAppsCountProvider).valueOrNull, 3);

      h.container.invalidate(openAppsCountProvider);
      await Future<void>.delayed(Duration.zero);
      // Refetch in volo: il badge NON deve sparire — valueOrNull conserva 3.
      expect(h.container.read(openAppsCountProvider).valueOrNull, 3);

      second.complete(const OpenAppsCountSnapshot(count: 8, seq: 2));
      await h.container.read(openAppsCountProvider.future);
      expect(h.container.read(openAppsCountProvider).valueOrNull, 8);
    });

    test('push con seq più vecchio del già applicato viene scartato',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      final events = StreamController<KoruServiceEvent>.broadcast();
      addTearDown(events.close);
      when(() => h.events.events()).thenAnswer((_) => events.stream);
      when(() => h.blocking.getOpenAppsCount()).thenAnswer(
          (_) async => const OpenAppsCountSnapshot(count: 2, seq: 5));
      keepProviderAlive(h.container, openAppsCountProvider);

      expect(await h.container.read(openAppsCountProvider.future), 2);

      // Evento ritardatario (in coda sul main handler nativo prima del
      // pull): seq 3 < 5 → non deve regredire il badge.
      events.add(const OpenAppsCountEvent(count: 9, seq: 3));
      await Future<void>.delayed(Duration.zero);

      expect(h.container.read(openAppsCountProvider).valueOrNull, 2);
    });

    test('pull stale non sovrascrive il push più recente (race seq)',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      final events = StreamController<KoruServiceEvent>.broadcast();
      addTearDown(events.close);
      when(() => h.events.events()).thenAnswer((_) => events.stream);
      // Il pull resta in volo: il valore (count 3, seq 2) è stato letto
      // PRIMA di un reset nativo che pusha (count 0, seq 5).
      final pull = Completer<OpenAppsCountSnapshot>();
      when(() => h.blocking.getOpenAppsCount())
          .thenAnswer((_) => pull.future);
      keepProviderAlive(h.container, openAppsCountProvider);

      final first = h.container.read(openAppsCountProvider.future);
      events.add(const OpenAppsCountEvent(count: 0, seq: 5));
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(openAppsCountProvider).valueOrNull, 0);

      pull.complete(const OpenAppsCountSnapshot(count: 3, seq: 2));
      await first;

      // Il pull stale (seq 2 < 5) NON deve riportare il badge a 3.
      expect(h.container.read(openAppsCountProvider).valueOrNull, 0);
    });
  });

  group('recentsIconCapabilityProvider', () {
    void stubCapability(
      TestHarness h, {
      required bool a11y,
      required bool usage,
      required int mask,
    }) {
      when(() => h.permission.checkAccessibilityService())
          .thenAnswer((_) async => a11y);
      when(() => h.permission.checkUsageStatsPermission())
          .thenAnswer((_) async => usage);
      when(() => h.strict.getStrictModeOptions()).thenAnswer((_) async => mask);
    }

    test('tutto attivo → icona visibile, badge, tap abilitato', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      stubCapability(h, a11y: true, usage: true, mask: 0);

      final cap =
          await h.container.read(recentsIconCapabilityProvider.future);

      expect(cap.iconVisible, isTrue);
      expect(cap.badgeVisible, isTrue);
      expect(cap.tapEnabled, isTrue);
    });

    test('accessibilità OFF → icona nascosta', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      stubCapability(h, a11y: false, usage: true, mask: 0);

      final cap =
          await h.container.read(recentsIconCapabilityProvider.future);

      expect(cap.iconVisible, isFalse);
    });

    test('usage stats OFF → icona senza badge ma visibile', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      stubCapability(h, a11y: true, usage: false, mask: 0);

      final cap =
          await h.container.read(recentsIconCapabilityProvider.future);

      expect(cap.iconVisible, isTrue);
      expect(cap.badgeVisible, isFalse);
      expect(cap.tapEnabled, isTrue);
    });

    test('strict BLOCK_RECENT_APPS (bit 8) → tap disabilitato', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      stubCapability(
        h,
        a11y: true,
        usage: true,
        mask: StrictModeOption.blockRecentApps,
      );

      final cap =
          await h.container.read(recentsIconCapabilityProvider.future);

      expect(cap.iconVisible, isTrue);
      expect(cap.tapEnabled, isFalse);
    });

    test('altri bit strict NON disabilitano il tap', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      stubCapability(
        h,
        a11y: true,
        usage: true,
        mask: StrictModeOption.blockSettings |
            StrictModeOption.blockUninstalling,
      );

      final cap =
          await h.container.read(recentsIconCapabilityProvider.future);

      expect(cap.tapEnabled, isTrue);
    });
  });
}
