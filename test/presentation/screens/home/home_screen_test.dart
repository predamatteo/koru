import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/platform/service_event_channel.dart';
import 'package:koru/presentation/providers/accessibility_health_provider.dart';
import 'package:koru/presentation/providers/active_profile_provider.dart';
import 'package:koru/presentation/providers/app_limits_provider.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/providers/profile_providers.dart';
import 'package:koru/presentation/providers/reel_counts_provider.dart';
import 'package:koru/presentation/providers/statistics_providers.dart';
import 'package:koru/presentation/screens/home/home_screen.dart';
import 'package:koru/presentation/screens/home/widgets/reels_scrolled_card.dart';
import 'package:koru/presentation/screens/home/widgets/today_limits_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_helpers/provider_test_utils.dart';

/// Stub del notifier dei limiti: la Home monta [TodayLimitsCard], che senza
/// questo andrebbe a chiamare il canale nativo.
class _StubAppLimitsNotifier extends AppLimitsNotifier {
  _StubAppLimitsNotifier(this._limits);

  final Map<String, AppLimitConfig> _limits;

  @override
  Future<Map<String, AppLimitConfig>> build() async => _limits;
}

/// Harness con tutte le sorgenti della dashboard stubate. `blocksToday` è
/// l'unico dato che i test fanno variare.
TestHarness _harness({int blocksToday = 0, int reelsToday = 0}) {
  final h = buildTestContainer(extra: [
    // Banner di salute nascosto: non fa parte di ciò che si sta misurando e
    // altrimenti si prende la prima riga della lista.
    accessibilityHealthProvider.overrideWith((ref) => Stream.value(true)),
    // `activeProfilesProvider` rivaluta "attivo ora" su uno `Stream.periodic`
    // di un minuto: sotto `pumpAndSettle` (che avanza l'orologio finto finché
    // qualcuno chiede frame) quello stream non finisce MAI e il test resta
    // appeso. Va sostituito con un valore fisso, non solo stubato a monte.
    activeProfilesProvider.overrideWith((ref) => Stream.value(const [])),
    // Ogni `Drift.watch` VIVO va sostituito con uno stream finito, non solo
    // per isolare il test: sotto `testWidgets` il corpo gira dentro FakeAsync,
    // e con una stream-query aperta il `db.close()` del teardown non completa
    // mai — il test resta appeso e tutti quelli dopo non partono nemmeno.
    profilesProvider.overrideWith((ref) => Stream.value(const [])),
    blocksTodayCountProvider.overrideWith((ref) => Stream.value(blocksToday)),
    reelCountsTodayProvider.overrideWith(
      (ref) async => ReelCounts({
        if (reelsToday > 0) 'INSTAGRAM_REELS': reelsToday,
      }),
    ),
    reelCountsWeekProvider.overrideWith((ref) async => const []),
    installedAppsProvider.overrideWith((ref) async => const []),
    installedPackageNamesProvider.overrideWith((ref) async => const <String>{}),
    appLimitsProvider.overrideWith(() => _StubAppLimitsNotifier(const {})),
  ]);
  // `blockingEventsRefresherProvider` è uno dei provider "sempre attivi" che la
  // Home osserva: senza questo stub si attacca a un EventChannel inesistente.
  when(() => h.events.events()).thenAnswer(
    (_) => const Stream<KoruServiceEvent>.empty(),
  );
  return h;
}

/// Pump espliciti invece di `pumpAndSettle`. La dashboard tiene vivi provider
/// che riprogrammano lavoro all'infinito (il ticker da 15s di
/// [TodayLimitsCard], i refresher di eventi): `pumpAndSettle` avanza
/// l'orologio finto finché qualcuno chiede un frame, quindi non convergerebbe
/// mai. Tre frame bastano: i FutureProvider stubati risolvono in microtask.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

Widget _wrap(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/stats',
        builder: (_, _) => const Scaffold(body: Text('StatsPage')),
      ),
      GoRoute(
        path: '/profiles',
        builder: (_, _) => const Scaffold(body: Text('ProfilesPage')),
      ),
      GoRoute(
        path: '/settings/app-limits',
        builder: (_, _) => const Scaffold(body: Text('AppLimitsPage')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('HomeScreen — riga blocchi + reel', () {
    testWidgets('i due contatori stanno sulla stessa riga in rapporto 1:2',
        (tester) async {
      // È l'unica cosa che rende la riga quello che è: i blocchi sono un
      // intero solo e non meritano più spazio di così, il contatore reel porta
      // con sé confronto con la media e righe per-sorgente.
      final h = _harness(blocksToday: 12, reelsToday: 47);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);

      final blocks = tester.getRect(find.text('Blocks'));
      final reels = tester.getRect(find.byType(ReelsScrolledCard));

      // Affiancati, non impilati: la tessera dei blocchi sta tutta a sinistra
      // del contatore reel.
      expect(blocks.right, lessThan(reels.left));

      final blocksTile = tester.getRect(
        find.ancestor(
          of: find.text('Blocks'),
          matching: find.byType(Container),
        ).first,
      );
      // 1:2 — `Expanded(flex:1)` e `Expanded(flex:2)` si spartiscono lo spazio
      // RESIDUO dopo il gap, quindi il rapporto è esatto fra le due tessere.
      expect(reels.width, closeTo(blocksTile.width * 2, 1));
    });

    testWidgets('le due tessere hanno la stessa altezza', (tester) async {
      // `CrossAxisAlignment.stretch`: senza, la tessera dei blocchi resterebbe
      // alta la metà e la riga avrebbe un fondo frastagliato.
      final h = _harness(blocksToday: 3, reelsToday: 80);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);

      final blocksTile = tester.getRect(
        find.ancestor(
          of: find.text('Blocks'),
          matching: find.byType(Container),
        ).first,
      );
      final reels = tester.getRect(find.byType(ReelsScrolledCard));
      expect(blocksTile.height, closeTo(reels.height, 0.5));
    });

    testWidgets('il conteggio dei blocchi è quello di oggi', (tester) async {
      final h = _harness(blocksToday: 12);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Blocks'), findsOneWidget);
    });

    testWidgets('il tap sui blocchi porta alle Statistiche', (tester) async {
      // Senza destinazione il numero sarebbe un vicolo cieco: il suo dettaglio
      // (donut Blocked/Skipped, breakdown per-app) vive solo in /stats.
      final h = _harness(blocksToday: 5);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);

      await tester.tap(find.text('Blocks'));
      // Durata generosa: copre la transizione di rotta senza aspettare che la
      // dashboard si quieti (vedi [_settle]).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('StatsPage'), findsOneWidget);
    });

    testWidgets('la card dei limiti resta sotto la riga', (tester) async {
      final h = _harness();
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);

      final reels = tester.getRect(find.byType(ReelsScrolledCard));
      final limits = tester.getRect(find.byType(TodayLimitsCard));
      expect(limits.top, greaterThan(reels.bottom));
    });
  });
}
