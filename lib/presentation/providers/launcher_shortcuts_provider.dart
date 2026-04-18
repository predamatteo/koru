import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/di/providers.dart';

/// Due shortcut sui lati del launcher (sinistra / destra) personalizzabili.
/// Default: dialer di sistema a sinistra, fotocamera a destra (risolti lazy
/// al primo accesso). L'utente può sostituirli da Settings → Launcher
/// scegliendo una qualsiasi app installata.
enum LauncherShortcutSlot { left, right }

class LauncherShortcuts {
  const LauncherShortcuts({this.leftPackage, this.rightPackage});

  /// null = nessuna override → usa il default di sistema risolto runtime.
  final String? leftPackage;
  final String? rightPackage;

  String? packageFor(LauncherShortcutSlot slot) =>
      slot == LauncherShortcutSlot.left ? leftPackage : rightPackage;

  LauncherShortcuts copyWith({String? leftPackage, String? rightPackage, bool clearLeft = false, bool clearRight = false}) =>
      LauncherShortcuts(
        leftPackage: clearLeft ? null : (leftPackage ?? this.leftPackage),
        rightPackage: clearRight ? null : (rightPackage ?? this.rightPackage),
      );
}

class LauncherShortcutsNotifier extends Notifier<LauncherShortcuts> {
  @override
  LauncherShortcuts build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    return LauncherShortcuts(
      leftPackage:
          hive.get<String>(HiveKeys.uiStateBox, HiveKeys.launcherLeftShortcut),
      rightPackage:
          hive.get<String>(HiveKeys.uiStateBox, HiveKeys.launcherRightShortcut),
    );
  }

  Future<void> set(LauncherShortcutSlot slot, String packageName) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    final key = slot == LauncherShortcutSlot.left
        ? HiveKeys.launcherLeftShortcut
        : HiveKeys.launcherRightShortcut;
    await hive.put(HiveKeys.uiStateBox, key, packageName);
    state = slot == LauncherShortcutSlot.left
        ? state.copyWith(leftPackage: packageName)
        : state.copyWith(rightPackage: packageName);
  }

  Future<void> clear(LauncherShortcutSlot slot) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    final key = slot == LauncherShortcutSlot.left
        ? HiveKeys.launcherLeftShortcut
        : HiveKeys.launcherRightShortcut;
    await hive.delete(HiveKeys.uiStateBox, key);
    state = slot == LauncherShortcutSlot.left
        ? state.copyWith(clearLeft: true)
        : state.copyWith(clearRight: true);
  }
}

final launcherShortcutsProvider =
    NotifierProvider<LauncherShortcutsNotifier, LauncherShortcuts>(
  LauncherShortcutsNotifier.new,
);

/// Risolve il package di default per uno slot (dialer per left, camera per
/// right). Cached una volta via FutureProvider.family.
final defaultShortcutPackageProvider =
    FutureProvider.family<String?, LauncherShortcutSlot>((ref, slot) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return slot == LauncherShortcutSlot.left
      ? blocking.getDefaultDialerPackage()
      : blocking.getDefaultCameraPackage();
});

/// Package effettivo da usare per lo slot: override user se presente,
/// altrimenti il default di sistema.
final effectiveShortcutPackageProvider =
    Provider.family<String?, LauncherShortcutSlot>((ref, slot) {
  final shortcuts = ref.watch(launcherShortcutsProvider);
  final override = shortcuts.packageFor(slot);
  if (override != null && override.isNotEmpty) return override;
  return ref.watch(defaultShortcutPackageProvider(slot)).valueOrNull;
});
