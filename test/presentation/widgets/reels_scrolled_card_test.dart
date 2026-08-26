import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/reel_counts_provider.dart';
import 'package:koru/presentation/screens/home/widgets/reels_scrolled_card.dart';

import '../../_helpers/provider_test_utils.dart';

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: ReelsScrolledCard()),
      ),
    );

ReelDayCounts _day(int dayStartMs, int instagram) => ReelDayCounts(
      dayStartMs: dayStartMs,
      counts: ReelCounts({if (instagram > 0) 'INSTAGRAM_REELS': instagram}),
    );

void main() {
  group('ReelsScrolledCard', () {
    // Il punto della card: è un elemento FISSO della dashboard. Non ha più un
    // interruttore che la spenga e non sparisce a zero — nasconderla rendeva
    // "non ho scrollato" indistinguibile da "la detection si è rotta dopo un
    // update di Instagram", cioè trasformava un guasto in un complimento.

    testWidgets('resta visibile a zero reel', (tester) async {
      final h = buildTestContainer(extra: [
        reelCountsTodayProvider.overrideWith((ref) async => ReelCounts.empty),
        reelCountsWeekProvider.overrideWith((ref) async => const []),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await tester.pumpAndSettle();

      expect(find.text('SCROLLED TODAY'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('reels'), findsOneWidget);
      expect(find.text('None today'), findsOneWidget);
      // Nessuna riga per sorgente: a zero non c'è niente da ripartire.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('resta visibile mentre il conteggio non è ancora arrivato',
        (tester) async {
      // Primissimo frame del cold start: il canale nativo non ha ancora
      // risposto. La card occupa comunque il suo posto e mostra 0, invece di
      // far saltare il layout della dashboard quando il dato atterra.
      final never = Completer<ReelCounts>();
      addTearDown(() => never.complete(ReelCounts.empty));
      final h = buildTestContainer(extra: [
        reelCountsTodayProvider.overrideWith((ref) => never.future),
        reelCountsWeekProvider.overrideWith((ref) async => const []),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await tester.pump();

      expect(find.text('SCROLLED TODAY'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('mostra il totale e la ripartizione per sorgente',
        (tester) async {
      final h = buildTestContainer(extra: [
        reelCountsTodayProvider.overrideWith(
          (ref) async => const ReelCounts({
            'INSTAGRAM_REELS': 12,
            'YOUTUBE_SHORTS': 8,
          }),
        ),
        reelCountsWeekProvider.overrideWith((ref) async => const []),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await tester.pumpAndSettle();

      expect(find.text('20'), findsOneWidget);
      expect(find.text('Instagram Reels'), findsOneWidget);
      expect(find.text('YouTube Shorts'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('singolare a un reel solo', (tester) async {
      final h = buildTestContainer(extra: [
        reelCountsTodayProvider.overrideWith(
          (ref) async => const ReelCounts({'INSTAGRAM_REELS': 1}),
        ),
        reelCountsWeekProvider.overrideWith((ref) async => const []),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await tester.pumpAndSettle();

      expect(find.text('reel'), findsOneWidget);
      expect(find.text('reels'), findsNothing);
    });

    testWidgets('a zero cita la media quando c\'è storico', (tester) async {
      // Oggi è escluso dalla media (giorno parziale): la settimana parte dal
      // giorno corrente, quindi i giorni "passati" sono quelli dopo il primo.
      final h = buildTestContainer(extra: [
        reelCountsTodayProvider.overrideWith((ref) async => ReelCounts.empty),
        reelCountsWeekProvider.overrideWith(
          (ref) async => [_day(3, 0), _day(2, 10), _day(1, 10)],
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await tester.pumpAndSettle();

      expect(find.text('None today — your average is 10'), findsOneWidget);
    });
  });
}
