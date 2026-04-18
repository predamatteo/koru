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
