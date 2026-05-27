import 'dart:async';
import 'dart:developer' as developer;

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
    final saved = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setAppDailyLimits(next);
    // CR-09: il nativo ora ritorna il vero esito della scrittura atomica dello
    // store. Se `false`, il cap (stato di enforcement) NON e' stato persistito:
    // lo stato Riverpod ottimistico diverge dal disco. Lo segnaliamo invece di
    // assumere il successo silenziosamente come prima.
    if (!saved) {
      developer.log(
        'setAppDailyLimits FAILED to persist (pkg=$packageName minutes=$minutes)',
        name: 'AppLimits',
        level: 1000,
      );
    }
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
    final saved = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setAppDailyLimits(next);
    // CR-09: propaga l'esito reale del salvataggio (vedi setLimit).
    if (!saved) {
      developer.log(
        'setAppDailyLimits FAILED to persist strict flag '
        '(pkg=$packageName strict=$strict)',
        name: 'AppLimits',
        level: 1000,
      );
    }
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

  /// Rimuove entry per package che non sono piu' installate sul device.
  /// No-op se non ci sono entries stale. La pulizia e' idempotente: se
  /// piu' callsite la invocano in rapida successione (es. resume +
  /// PACKAGE_REMOVED arrivati ravvicinati), il secondo trova nulla da
  /// fare e ritorna subito.
  ///
  /// Senza questa pulizia il JSON `koru_app_limits.json` cresce
  /// indefinitamente con app disinstallate, che riappaiono nella card
  /// "Today's limits" come voci fantasma.
  Future<void> cleanupUninstalled(Set<String> installedPackages) async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    final cleaned = <String, AppLimitConfig>{
      for (final e in current.entries)
        if (installedPackages.contains(e.key)) e.key: e.value,
    };
    if (cleaned.length == current.length) return;
    state = AsyncData(cleaned);
    final saved = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setAppDailyLimits(cleaned);
    // CR-09: propaga l'esito reale del salvataggio (vedi setLimit).
    if (!saved) {
      developer.log(
        'setAppDailyLimits FAILED to persist cleanup '
        '(${current.length - cleaned.length} stale entries)',
        name: 'AppLimits',
        level: 1000,
      );
    }
  }
}

final appLimitsProvider =
    AsyncNotifierProvider<AppLimitsNotifier, Map<String, AppLimitConfig>>(
  AppLimitsNotifier.new,
);

/// Minuti di utilizzo oggi (foreground) per `packageName`. Ricomputato a
/// ogni rebuild del provider — invalidare per refresh. I consumer che
/// mostrano un timer in tempo reale (TodayLimitsCard) gestiscono il polling
/// internamente con un `Timer.periodic` + `ref.invalidate`.
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
