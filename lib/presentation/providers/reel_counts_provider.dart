import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';

/// Reel/short scrollati oggi, per sorgente.
///
/// Il dato canonico vive in un file nativo (`koru_reel_counts.json`) scritto
/// dal motore di enforcement, non in Drift: qui si legge e basta. È volutamente
/// una `FutureProvider` senza `keepAlive` — la home la ricalcola quando torna in
/// vista, e i confronti sono col ritorno dall'app, non con l'ultimo swipe.
///
/// Il refresh arriva dall'invalidazione sul resume in `events_refresher.dart`:
/// il contatore cresce mentre Koru è in background, quindi il rientro nell'app
/// è il momento in cui il numero mostrato è più vecchio.
final reelCountsTodayProvider = FutureProvider<ReelCounts>((ref) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getReelCountsToday();
});

/// Ultimi 7 giorni, dal più recente al più vecchio, giorni vuoti inclusi.
/// Serve alla card della home per la media settimanale: un numero da solo non
/// dice se oggi è una giornata storta o normale.
final reelCountsWeekProvider = FutureProvider<List<ReelDayCounts>>((ref) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getReelCountsHistory(days: 7);
});

/// Media giornaliera dei 6 giorni PRECEDENTI a oggi (oggi escluso).
///
/// Oggi è escluso di proposito: è un giorno parziale, e includerlo renderebbe
/// il confronto "oggi vs media" sistematicamente lusinghiero al mattino.
/// `null` quando non c'è ancora storico su cui basare un confronto — meglio non
/// mostrare nulla che mostrare una media costruita su un giorno solo.
final reelWeeklyAverageProvider = Provider<int?>((ref) {
  final days = ref.watch(reelCountsWeekProvider).valueOrNull;
  if (days == null || days.length < 2) return null;
  final past = days.skip(1).toList(growable: false);
  if (past.every((d) => d.total == 0)) return null;
  final sum = past.fold<int>(0, (acc, d) => acc + d.total);
  return (sum / past.length).round();
});

/// Interruttore del contatore. Vive lato nativo e non in Hive: lo legge anche
/// l'AccessibilityService, che a Hive non può accedere. Spegnendolo il nativo
/// smette pure di osservare Instagram e YouTube, quindi non è cosmetico.
class ReelCounterEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    return blocking.isReelCounterEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    // Ottimistico: l'interruttore deve rispondere al tocco, non al round-trip
    // del canale. In caso di fallimento torniamo indietro — un toggle che resta
    // dove l'utente l'ha messo ma non ha salvato è peggio di uno che rimbalza.
    final previous = state.valueOrNull;
    state = AsyncData(enabled);
    final saved = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setReelCounterEnabled(enabled);
    if (!saved) {
      developer.log(
        'setReelCounterEnabled FAILED to persist (enabled=$enabled)',
        name: 'ReelCounter',
        level: 1000,
      );
      if (previous != null) state = AsyncData(previous);
      return;
    }
    ref.invalidate(reelCountsTodayProvider);
    ref.invalidate(reelCountsWeekProvider);
  }
}

final reelCounterEnabledProvider =
    AsyncNotifierProvider<ReelCounterEnabledNotifier, bool>(
  ReelCounterEnabledNotifier.new,
);
