import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';
import 'statistics_providers.dart';

/// Screen-time aggregato nel periodo corrente. Usa UsageStatsManager
/// tramite `blocking.getUsageStats(startMs, endMs)`.
final periodUsageProvider = FutureProvider<List<AppUsageInfo>>((ref) async {
  final range = ref.watch(selectedPeriodProvider).currentRangeMs();
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getUsageStats(startMs: range.from, endMs: range.to);
});

/// Screen-time totale del periodo (ms).
final periodScreenTimeMsProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(periodUsageProvider.future);
  return list.fold<int>(0, (sum, a) => sum + a.totalTimeMs);
});

/// Screen-time del periodo precedente (per calcolare delta %).
final previousPeriodScreenTimeMsProvider = FutureProvider<int>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final range = period.currentRangeMs();
  final windowMs = range.to - range.from;
  final prevFrom = range.from - windowMs;
  final prevTo = range.from;
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  final list = await blocking.getUsageStats(startMs: prevFrom, endMs: prevTo);
  return list.fold<int>(0, (sum, a) => sum + a.totalTimeMs);
});

/// Top N app del periodo per tempo in foreground (default N=5).
final topAppsByUsageProvider =
    FutureProvider.family<List<AppUsageInfo>, int>((ref, limit) async {
  final list = await ref.watch(periodUsageProvider.future);
  final sorted = [...list]..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs));
  return sorted.take(limit).toList(growable: false);
});

/// Giorno selezionato nella vista settimana, come mezzanotte locale in ms,
/// oppure `null` = aggregato dell'intera settimana.
///
/// È stato UI puro: viene resettato a `null` quando si cambia periodo
/// (vedi `_PeriodSwitcher`) e — come `selectedPeriodProvider` — è escluso di
/// proposito dal pull-to-refresh, che altrimenti cancellerebbe la scelta.
final selectedStatsDayProvider = StateProvider<int?>((_) => null);

/// Breakdown per-giorno dell'utilizzo negli ultimi 7 giorni (oggi incluso):
/// esattamente 7 [DailyUsage] in ordine crescente, con i giorni senza
/// utilizzo riempiti a zero. Una sola passata nativa di `queryEvents`
/// (`getUsageStatsByDay`) copre tutta la finestra.
///
/// I `dayStartMs` sono costruiti con `DateTime(y, m, d - 6 + i)` (non con
/// `add(Duration(days:))`) per restare allineati alla mezzanotte locale anche
/// a cavallo dei cambi di ora legale, così le chiavi combaciano con quelle
/// calcolate lato nativo.
final weeklyDailyUsageProvider = FutureProvider<List<DailyUsage>>((ref) async {
  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month, now.day - 6);
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  final raw = await blocking.getUsageStatsByDay(
    startMs: firstDay.millisecondsSinceEpoch,
    endMs: now.millisecondsSinceEpoch,
  );
  final byDay = {for (final d in raw) d.dayStartMs: d};
  return List<DailyUsage>.generate(7, (i) {
    final day = DateTime(now.year, now.month, now.day - 6 + i);
    final key = day.millisecondsSinceEpoch;
    return byDay[key] ?? DailyUsage(dayStartMs: key, apps: const []);
  }, growable: false);
});

/// Il [DailyUsage] del giorno selezionato nella vista settimana, oppure
/// `null` se nessun giorno è selezionato (= aggregato settimana) o se i dati
/// settimanali non sono ancora pronti. Le card screen-time / top-apps lo
/// usano per mostrare il singolo giorno invece dell'intera settimana.
final selectedDayUsageProvider = Provider<DailyUsage?>((ref) {
  final selected = ref.watch(selectedStatsDayProvider);
  if (selected == null) return null;
  final week = ref.watch(weeklyDailyUsageProvider).valueOrNull;
  if (week == null) return null;
  for (final d in week) {
    if (d.dayStartMs == selected) return d;
  }
  return null;
});
