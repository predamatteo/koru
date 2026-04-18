import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'achievements_provider.dart';

/// Mappa `packageName → minuti consentiti al giorno`. 0 o assente = nessun
/// limite. Stato canonico persistito nel file JSON nativo
/// `koru_app_limits.json` (letto dal processo `:accessibility` a ogni
/// apertura app). Il Dart chiama `setAppDailyLimits` per riallineare.
class AppLimitsNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    return blocking.getAppDailyLimits();
  }

  Future<void> setLimit(String packageName, int minutes) async {
    final current = state.valueOrNull ?? {};
    final next = {...current};
    if (minutes <= 0) {
      next.remove(packageName);
    } else {
      next[packageName] = minutes;
    }
    state = AsyncData(next);
    await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setAppDailyLimits(next);
    await ref.read(achievementEvaluationProvider.notifier).trigger();
  }

  Future<void> clear(String packageName) => setLimit(packageName, 0);
}

final appLimitsProvider =
    AsyncNotifierProvider<AppLimitsNotifier, Map<String, int>>(
  AppLimitsNotifier.new,
);

/// Minuti di utilizzo oggi (foreground) per `packageName`. Ricomputato a
/// ogni rebuild del provider — invalidare per refresh.
final usageTodayMinutesProvider =
    FutureProvider.family<int, String>((ref, packageName) async {
  final ms = await ref
      .read(platformChannelServiceProvider)
      .blocking
      .getUsageTodayMs(packageName);
  return (ms / 60000).floor();
});
