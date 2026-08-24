import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/reel_counts_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

/// Test del contatore reel lato Dart: decodifica del wire-format e media
/// settimanale.
///
/// Il punto delicato non è l'aritmetica ma **cosa NON deve succedere**: un
/// totale che cala perché il nativo ha imparato a contare una piattaforma nuova,
/// e una media che si costruisce includendo oggi (che è un giorno parziale e
/// renderebbe il confronto sempre lusinghiero al mattino).
void main() {
  ReelDayCounts day(int dayStart, Map<String, int> counts) =>
      ReelDayCounts(dayStartMs: dayStart, counts: ReelCounts(counts));

  group('ReelCounts.fromMap', () {
    test('decodes known sources', () {
      final counts = ReelCounts.fromMap({
        'INSTAGRAM_REELS': 84,
        'YOUTUBE_SHORTS': 48,
      });
      expect(counts.forSource(ReelSource.instagramReels), 84);
      expect(counts.forSource(ReelSource.youtubeShorts), 48);
      expect(counts.total, 132);
      expect(counts.isEmpty, isFalse);
    });

    test('counts unknown sources in the total', () {
      // Il nativo può imparare a contare una piattaforma prima che questo lato
      // sappia come chiamarla: il totale deve comprenderla comunque, altrimenti
      // aggiungere una sorgente farebbe CALARE il numero mostrato all'utente.
      final counts = ReelCounts.fromMap({
        'INSTAGRAM_REELS': 10,
        'TIKTOK_FEED': 5,
      });
      expect(counts.total, 15);
      expect(counts.forSource(ReelSource.instagramReels), 10);
      expect(counts.forSource(ReelSource.youtubeShorts), 0);
    });

    test('drops non-positive and malformed entries', () {
      final counts = ReelCounts.fromMap({
        'INSTAGRAM_REELS': 0,
        'YOUTUBE_SHORTS': -4,
        'BROKEN': null,
      });
      expect(counts.total, 0);
      expect(counts.isEmpty, isTrue);
    });

    test('empty map is empty', () {
      expect(ReelCounts.fromMap(const {}).isEmpty, isTrue);
      expect(ReelCounts.empty.total, 0);
    });
  });

  group('ReelDayCounts.fromMap', () {
    test('decodes day + counts', () {
      final decoded = ReelDayCounts.fromMap({
        'dayStart': 1755129600000,
        'counts': {'INSTAGRAM_REELS': 12},
      });
      expect(decoded.dayStartMs, 1755129600000);
      expect(decoded.total, 12);
    });

    test('tolerates a missing counts map', () {
      // I giorni vuoti arrivano dal nativo con la mappa a zero voci; una
      // risposta senza la chiave non deve far esplodere il parsing.
      final decoded = ReelDayCounts.fromMap({'dayStart': 1755129600000});
      expect(decoded.total, 0);
    });
  });

  group('ReelSource', () {
    test('wire ids round-trip', () {
      for (final source in ReelSource.values) {
        expect(ReelSource.fromWireId(source.wireId), source);
      }
      expect(ReelSource.fromWireId('NOPE'), isNull);
    });
  });

  group('reelCountsTodayProvider', () {
    test('reads the counts from the native channel', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.blocking.getReelCountsToday()).thenAnswer(
        (_) async => const ReelCounts({'INSTAGRAM_REELS': 7}),
      );

      final counts = await h.container.read(reelCountsTodayProvider.future);
      expect(counts.total, 7);
    });
  });

  group('reelWeeklyAverageProvider', () {
    Future<int?> averageOf(List<ReelDayCounts> days) async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.blocking.getReelCountsHistory(days: any(named: 'days')))
          .thenAnswer((_) async => days);
      await h.container.read(reelCountsWeekProvider.future);
      return h.container.read(reelWeeklyAverageProvider);
    }

    test('excludes today from the average', () async {
      // Oggi = 100 (giorno parziale), i 3 precedenti = 10/20/30 → media 20.
      // Includendo oggi verrebbe 40, cioè un confronto che assolverebbe
      // sistematicamente le giornate storte.
      final average = await averageOf([
        day(4, {'INSTAGRAM_REELS': 100}),
        day(3, {'INSTAGRAM_REELS': 10}),
        day(2, {'INSTAGRAM_REELS': 20}),
        day(1, {'INSTAGRAM_REELS': 30}),
      ]);
      expect(average, 20);
    });

    test('rounds to the nearest integer', () async {
      final average = await averageOf([
        day(4, {'INSTAGRAM_REELS': 0}),
        day(3, {'INSTAGRAM_REELS': 10}),
        day(2, {'INSTAGRAM_REELS': 11}),
      ]);
      expect(average, 11); // (10 + 11) / 2 = 10.5 → 11
    });

    test('is null when there is no history to compare against', () async {
      // Primo giorno di utilizzo: una "media" costruita sul nulla sarebbe un
      // confronto inventato.
      final average = await averageOf([
        day(2, {'INSTAGRAM_REELS': 40}),
        day(1, const {}),
      ]);
      expect(average, isNull);
    });

    // Un `averageOf` per test: l'helper costruisce un container (e un db Drift)
    // a chiamata, e due nello stesso test fanno emettere a Drift l'avviso
    // "database creato più volte".
    test('is null with a single day of history', () async {
      expect(await averageOf([day(1, {'INSTAGRAM_REELS': 5})]), isNull);
    });

    test('is null with no history at all', () async {
      expect(await averageOf(const []), isNull);
    });
  });

  group('reelCounterEnabledProvider', () {
    test('reads the current value from native', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.blocking.isReelCounterEnabled()).thenAnswer((_) async => false);

      expect(await h.container.read(reelCounterEnabledProvider.future), isFalse);
    });

    test('persists the new value', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.blocking.isReelCounterEnabled()).thenAnswer((_) async => true);
      when(() => h.blocking.setReelCounterEnabled(any()))
          .thenAnswer((_) async => true);

      await h.container.read(reelCounterEnabledProvider.future);
      await h.container.read(reelCounterEnabledProvider.notifier).setEnabled(false);

      verify(() => h.blocking.setReelCounterEnabled(false)).called(1);
      expect(h.container.read(reelCounterEnabledProvider).valueOrNull, isFalse);
    });

    test('rolls back when the native write fails', () async {
      // Un interruttore che resta dove l'utente l'ha messo senza aver salvato
      // tornerebbe indietro al riavvio, senza spiegazioni.
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.blocking.isReelCounterEnabled()).thenAnswer((_) async => true);
      when(() => h.blocking.setReelCounterEnabled(any()))
          .thenAnswer((_) async => false);

      await h.container.read(reelCounterEnabledProvider.future);
      await h.container.read(reelCounterEnabledProvider.notifier).setEnabled(false);

      expect(h.container.read(reelCounterEnabledProvider).valueOrNull, isTrue);
    });
  });
}
