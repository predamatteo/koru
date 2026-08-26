import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/daos/intention_usage_events_dao.dart';
import '../../data/database/daos/restricted_access_events_dao.dart';
import '../../domain/entities/statistics_period.dart';

final selectedPeriodProvider =
    StateProvider<StatisticsPeriod>((_) => StatisticsPeriod.today);

/// Di quanti giorni la schermata Statistiche è indietro rispetto a oggi.
///
/// `0` = oggi (il default), `1` = ieri, … fino a
/// [StatisticsPeriod.maxDaysBack]. Vale per il periodo "Today": la vista
/// settimana ha già il suo drill-down per-giorno dal grafico, e navigare fra
/// settimane mostrerebbe soprattutto zeri (la ritenzione degli eventi Android
/// non arriva alla settimana scorsa).
///
/// Come [selectedPeriodProvider] è stato di UI: il pull-to-refresh non lo
/// tocca, altrimenti aggiornare cancellerebbe il giorno che si sta guardando.
/// Viene invece azzerato quando si cambia periodo (vedi `_PeriodSwitcher`).
final selectedDayOffsetProvider = StateProvider<int>((_) => 0);

/// Giorno selezionato nella vista settimana, come mezzanotte locale in ms,
/// oppure `null` = aggregato dell'intera settimana.
///
/// Terzo pezzo dello stato UI delle Statistiche (con [selectedPeriodProvider] e
/// [selectedDayOffsetProvider]): stanno insieme perché si azzerano insieme,
/// vedi [resetStatsView]. Escluso di proposito dal pull-to-refresh, che
/// altrimenti cancellerebbe la scelta.
final selectedStatsDayProvider = StateProvider<int?>((_) => null);

/// Firma di `ref.read`, condivisa da `Ref` (provider, listener) e `WidgetRef`
/// (widget). Serve solo a [resetStatsView], che va chiamata da entrambi i lati
/// e non ha un tipo comune da cui prenderli.
typedef StatsRefReader = T Function<T>(ProviderListenable<T> provider);

/// Riporta le Statistiche alla vista di partenza: **oggi**, nessun giorno del
/// grafico selezionato, nessuna navigazione indietro.
///
/// I tre provider sono stato UI globale e sopravvivono alla navigazione: senza
/// un reset esplicito, chi era andato a martedì o su "This week" ritrova quella
/// vista giorni dopo, e la schermata smette di rispondere alla domanda che ci
/// si aspetta apra ("com'è andata oggi?").
///
/// Va chiamata dai punti di INGRESSO in `/stats` e non dal `initState` della
/// schermata: i tab vivono in uno `StatefulShellRoute.indexedStack`, quindi
/// `StatisticsScreen` resta montata quando si cambia tab e `initState` non
/// verrebbe mai rieseguito.
void resetStatsView(StatsRefReader read) {
  read(selectedPeriodProvider.notifier).state = StatisticsPeriod.today;
  read(selectedStatsDayProvider.notifier).state = null;
  read(selectedDayOffsetProvider.notifier).state = 0;
}

/// La finestra corrente in date `YYYY-MM-DD`: periodo selezionato + eventuale
/// spostamento indietro. Unico punto da cui passano le query su Drift, così
/// non c'è modo di aggiungere una card che ignora la navigazione.
({String from, String to}) _range(Ref ref) => ref
    .watch(selectedPeriodProvider)
    .currentRange(shiftDays: ref.watch(selectedDayOffsetProvider));

/// Count di eventi BLOCK_TRIGGERED (eventType=0) nel periodo.
final blockTriggeredCountProvider = StreamProvider<int>((ref) {
  final range = _range(ref);
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
  final range = _range(ref);
  return ref
      .watch(restrictedAccessEventsDaoProvider)
      .watchCountEventsByTypeInRange(1, range.from, range.to);
});

/// Breakdown per-app (pkg + count + eventType), ordinato desc.
final perAppBreakdownProvider = StreamProvider<List<PerAppStatResult>>((ref) {
  final range = _range(ref);
  return ref
      .watch(restrictedAccessEventsDaoProvider)
      .watchPerAppBreakdown(range.from, range.to);
});

/// Intentions selezionate (title + count) ordinate desc.
final topIntentionsProvider = StreamProvider<List<IntentionUsageResult>>((ref) {
  final range = _range(ref);
  return ref
      .watch(intentionUsageEventsDaoProvider)
      .watchIntentionsUsages(range.from, range.to);
});
