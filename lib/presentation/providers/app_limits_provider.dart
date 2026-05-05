import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';
import 'achievements_provider.dart';

/// Mappa `packageName → AppLimitConfig`. Stato canonico persistito nel file
/// JSON nativo `koru_app_limits.json` (letto dal processo `:accessibility`
/// a ogni apertura app). Il Dart chiama `setAppDailyLimits` per riallineare.
class AppLimitsNotifier extends AsyncNotifier<Map<String, AppLimitConfig>> {
  @override
  Future<Map<String, AppLimitConfig>> build() async {
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    return blocking.getAppDailyLimits();
  }

  /// Imposta minuti + strict flag per [packageName]. Se `minutes <= 0` rimuove
  /// il limite. Se `strict` è omesso, conserva il valore corrente (o `true`
  /// per nuovi limiti).
  Future<void> setLimit(
    String packageName,
    int minutes, {
    bool? strict,
  }) async {
    final current = state.valueOrNull ?? {};
    final next = {...current};
    if (minutes <= 0) {
      next.remove(packageName);
    } else {
      final existing = current[packageName];
      next[packageName] = AppLimitConfig(
        minutes: minutes,
        strict: strict ?? existing?.strict ?? true,
      );
    }
    state = AsyncData(next);
    await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setAppDailyLimits(next);
    await ref.read(achievementEvaluationProvider.notifier).trigger();
  }

  /// Aggiorna solo lo strict flag senza toccare i minuti. No-op se il pkg
  /// non ha già un limite.
  Future<void> setStrict(String packageName, bool strict) async {
    final current = state.valueOrNull ?? {};
    final existing = current[packageName];
    if (existing == null) return;
    if (existing.strict == strict) return;
    final next = {...current};
    next[packageName] = existing.copyWith(strict: strict);
    state = AsyncData(next);
    await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setAppDailyLimits(next);
    // Quando si abilita lo strict mode, i contatori storici non sono più
    // rilevanti (la frizione progressiva non si applica); reset esplicito.
    if (strict) {
      await ref
          .read(platformChannelServiceProvider)
          .blocking
          .resetBypassCount(packageName);
    }
  }

  Future<void> clear(String packageName) => setLimit(packageName, 0);
}

final appLimitsProvider =
    AsyncNotifierProvider<AppLimitsNotifier, Map<String, AppLimitConfig>>(
  AppLimitsNotifier.new,
);

/// Minuti di utilizzo oggi (foreground) per `packageName`. Ricomputato a
/// ogni rebuild del provider — invalidare per refresh.
///
/// Arrotondamento: round al minuto più vicino invece di floor. Il floor
/// sottrae fino a 59s per display, facendo sembrare l'utilizzo reale
/// sistematicamente minore del vero.
final usageTodayMinutesProvider =
    FutureProvider.family<int, String>((ref, packageName) async {
  final ms = await ref
      .read(platformChannelServiceProvider)
      .blocking
      .getUsageTodayMs(packageName);
  return (ms / 60000).round();
});

/// Numero di bypass usati oggi per [packageName]. Usato dalla UI per
/// mostrare la pressione progressiva e dal motore di frizione.
final bypassCountTodayProvider =
    FutureProvider.family<int, String>((ref, packageName) async {
  return ref
      .read(platformChannelServiceProvider)
      .blocking
      .getBypassCountToday(packageName);
});
