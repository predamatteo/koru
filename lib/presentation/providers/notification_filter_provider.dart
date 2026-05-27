import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';

/// Stato canonico letto dal file JSON nativo
/// `koru_notification_filters.json` (fonte di verità cross-process).
class NotificationFilterNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    final list = await blocking.getSilencedPackages();
    return list.toSet();
  }

  Future<void> toggle(String packageName) async {
    final current = state.valueOrNull ?? const <String>{};
    final next = {...current};
    if (next.contains(packageName)) {
      next.remove(packageName);
    } else {
      next.add(packageName);
    }
    state = AsyncData(next);
    final saved = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setSilencedPackages(next.toList());
    // CR-09: il nativo ora ritorna il vero esito della scrittura atomica del
    // filtro. Se `false` il salvataggio NON e' andato a disco e lo stato
    // Riverpod ottimistico diverge; lo segnaliamo invece di assumere successo.
    if (!saved) {
      developer.log(
        'setSilencedPackages FAILED to persist toggle (pkg=$packageName)',
        name: 'NotifFilter',
        level: 1000,
      );
    }
  }

  Future<void> clearAll() async {
    state = const AsyncData(<String>{});
    final saved = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setSilencedPackages(const []);
    // CR-09: propaga l'esito reale del salvataggio (vedi toggle).
    if (!saved) {
      developer.log(
        'setSilencedPackages FAILED to persist clearAll',
        name: 'NotifFilter',
        level: 1000,
      );
    }
  }
}

final notificationFilterProvider =
    AsyncNotifierProvider<NotificationFilterNotifier, Set<String>>(
  NotificationFilterNotifier.new,
);

final notificationAccessGrantedProvider = FutureProvider<bool>((ref) async {
  return ref
      .read(platformChannelServiceProvider)
      .blocking
      .isNotificationAccessGranted();
});
