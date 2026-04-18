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
    await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setSilencedPackages(next.toList());
  }

  Future<void> clearAll() async {
    state = const AsyncData(<String>{});
    await ref
        .read(platformChannelServiceProvider)
        .blocking
        .setSilencedPackages(const []);
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
