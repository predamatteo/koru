import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/daos/intention_usage_events_dao.dart';
import '../../data/database/daos/restricted_access_events_dao.dart';
import '../../domain/entities/statistics_period.dart';

final selectedPeriodProvider =
    StateProvider<StatisticsPeriod>((_) => StatisticsPeriod.today);

/// Count di eventi BLOCK_TRIGGERED (eventType=0) nel periodo.
final blockTriggeredCountProvider = StreamProvider<int>((ref) {
  final range = ref.watch(selectedPeriodProvider).currentRange();
  return ref
      .watch(restrictedAccessEventsDaoProvider)
      .watchCountEventsByTypeInRange(0, range.from, range.to);
});

/// Count di eventi BLOCK_TRIGGERED **di oggi**, indipendente dal periodo
/// selezionato nella schermata Statistiche.
///
/// Esiste separato da [blockTriggeredCountProvider] perché quello segue
/// `selectedPeriodProvider`, che è stato UI globale mutato dallo switcher
/// Oggi/Settimana di `/stats`: la dashboard mostrava i blocchi della settimana
/// se l'utente aveva lasciato le Statistiche su "This week". Qui la finestra è
/// costruita localmente, quindi la Home dice sempre e solo "oggi".
final blocksTodayCountProvider = StreamProvider<int>((ref) {
  final range = StatisticsPeriod.today.currentRange();
  return ref
      .watch(restrictedAccessEventsDaoProvider)
      .watchCountEventsByTypeInRange(0, range.from, range.to);
});

/// Count di eventi BLOCK_SKIPPED (eventType=1) nel periodo.
final blockSkippedCountProvider = StreamProvider<int>((ref) {
  final range = ref.watch(selectedPeriodProvider).currentRange();
  return ref
      .watch(restrictedAccessEventsDaoProvider)
      .watchCountEventsByTypeInRange(1, range.from, range.to);
});

/// Breakdown per-app (pkg + count + eventType), ordinato desc.
final perAppBreakdownProvider = StreamProvider<List<PerAppStatResult>>((ref) {
  final range = ref.watch(selectedPeriodProvider).currentRange();
  return ref
      .watch(restrictedAccessEventsDaoProvider)
      .watchPerAppBreakdown(range.from, range.to);
});

/// Intentions selezionate (title + count) ordinate desc.
final topIntentionsProvider = StreamProvider<List<IntentionUsageResult>>((ref) {
  final range = ref.watch(selectedPeriodProvider).currentRange();
  return ref
      .watch(intentionUsageEventsDaoProvider)
      .watchIntentionsUsages(range.from, range.to);
});
