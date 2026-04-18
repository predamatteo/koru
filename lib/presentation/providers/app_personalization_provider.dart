import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/di/providers.dart';

/// Preferenze per-app del drawer launcher:
/// - **hidden**: app nascoste dalla lista (restano installate, solo non
///   mostrate — tipo Android "Hide apps" di stock launcher).
/// - **renamed**: label custom scelta dall'utente (es. "Chat" invece di
///   "WhatsApp") — aiuta a ridurre il dopamine hit brand-driven.
///
/// Entrambi persistiti in Hive `hiddenAppsBox`. Value object immutable.
class AppPersonalization {
  const AppPersonalization({
    this.hidden = const <String>{},
    this.renamed = const <String, String>{},
  });

  final Set<String> hidden;
  final Map<String, String> renamed;

  bool isHidden(String pkg) => hidden.contains(pkg);
  String? customName(String pkg) => renamed[pkg];
}

class AppPersonalizationNotifier extends Notifier<AppPersonalization> {
  @override
  AppPersonalization build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    final hidden = hive.getStringList(
      HiveKeys.hiddenAppsBox,
      HiveKeys.hiddenApps,
    ).toSet();
    final renamedRaw = hive.get<Map<dynamic, dynamic>>(
      HiveKeys.hiddenAppsBox,
      HiveKeys.renamedApps,
    );
    final renamed = <String, String>{};
    if (renamedRaw != null) {
      for (final e in renamedRaw.entries) {
        if (e.key is String && e.value is String) {
          renamed[e.key as String] = e.value as String;
        }
      }
    }
    return AppPersonalization(hidden: hidden, renamed: renamed);
  }

  Future<void> toggleHidden(String pkg) async {
    final next = {...state.hidden};
    if (next.contains(pkg)) {
      next.remove(pkg);
    } else {
      next.add(pkg);
    }
    await ref.read(hiveSettingsServiceProvider).setStringList(
          HiveKeys.hiddenAppsBox,
          HiveKeys.hiddenApps,
          next.toList(),
        );
    state = AppPersonalization(hidden: next, renamed: state.renamed);
  }

  Future<void> rename(String pkg, String? newName) async {
    final next = {...state.renamed};
    final trimmed = newName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      next.remove(pkg);
    } else {
      next[pkg] = trimmed;
    }
    await ref.read(hiveSettingsServiceProvider).put(
          HiveKeys.hiddenAppsBox,
          HiveKeys.renamedApps,
          next,
        );
    state = AppPersonalization(hidden: state.hidden, renamed: next);
  }

  Future<void> clearAll() async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.setStringList(
      HiveKeys.hiddenAppsBox,
      HiveKeys.hiddenApps,
      const [],
    );
    await hive.put(HiveKeys.hiddenAppsBox, HiveKeys.renamedApps, <String, String>{});
    state = const AppPersonalization();
  }
}

final appPersonalizationProvider =
    NotifierProvider<AppPersonalizationNotifier, AppPersonalization>(
  AppPersonalizationNotifier.new,
);
