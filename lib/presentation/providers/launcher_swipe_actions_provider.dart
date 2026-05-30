import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/constants/profile_types.dart';
import '../../core/di/providers.dart';
import 'app_limits_provider.dart';
import 'profile_providers.dart';

/// Due swipe LATERALI configurabili sulla home del launcher: sinistra e destra.
/// Ogni direzione esegue una [LauncherSwipeAction] personalizzabile da
/// Settings → Launcher.
///
/// Lo swipe verso l'alto (dal basso) NON è qui: è una gesture FISSA cablata su
/// "All apps" e non configurabile (vedi `LauncherHomeScreen._openAllApps`), così
/// l'accesso al drawer resta un gesto core garantito.
///
/// Stesso pattern di persistenza degli shortcut left/right del launcher
/// (vedi launcher_shortcuts_provider.dart): Hive `uiStateBox`, una chiave per
/// direzione, valore = [LauncherSwipeAction] serializzato a stringa.
enum LauncherSwipeDirection { left, right }

/// Tipo di azione assegnabile a uno swipe. Le app distraenti (profili
/// blocklist + limiti giornalieri) NON sono selezionabili come [openApp]
/// (vedi [distractingAppsProvider]).
enum LauncherSwipeActionType { none, allApps, appSearch, openApp }

/// Azione collegata a una direzione di swipe. [packageName] è valorizzato solo
/// per [LauncherSwipeActionType.openApp].
class LauncherSwipeAction {
  const LauncherSwipeAction(this.type, {this.packageName});

  final LauncherSwipeActionType type;
  final String? packageName;

  static const LauncherSwipeAction none =
      LauncherSwipeAction(LauncherSwipeActionType.none);

  /// Serializzazione compatta per Hive: `none` | `allApps` | `appSearch` |
  /// `openApp:<package>`.
  String encode() => switch (type) {
        LauncherSwipeActionType.none => 'none',
        LauncherSwipeActionType.allApps => 'allApps',
        LauncherSwipeActionType.appSearch => 'appSearch',
        LauncherSwipeActionType.openApp => 'openApp:${packageName ?? ''}',
      };

  /// Inverso di [encode]. `null`/stringhe non riconosciute → [none].
  /// Un `openApp:` senza package valido degrada a [none] (difensivo: un
  /// package svuotato non deve produrre uno swipe che lancia il vuoto).
  static LauncherSwipeAction decode(String? raw) {
    if (raw == null || raw.isEmpty) return none;
    if (raw == 'allApps') {
      return const LauncherSwipeAction(LauncherSwipeActionType.allApps);
    }
    if (raw == 'appSearch') {
      return const LauncherSwipeAction(LauncherSwipeActionType.appSearch);
    }
    if (raw.startsWith('openApp:')) {
      final pkg = raw.substring('openApp:'.length);
      if (pkg.isEmpty) return none;
      return LauncherSwipeAction(LauncherSwipeActionType.openApp,
          packageName: pkg);
    }
    return none;
  }

  @override
  bool operator ==(Object other) =>
      other is LauncherSwipeAction &&
      other.type == type &&
      other.packageName == packageName;

  @override
  int get hashCode => Object.hash(type, packageName);
}

String _hiveKeyFor(LauncherSwipeDirection dir) => switch (dir) {
      LauncherSwipeDirection.left => HiveKeys.launcherSwipeLeft,
      LauncherSwipeDirection.right => HiveKeys.launcherSwipeRight,
    };

class LauncherSwipeActionsNotifier
    extends Notifier<Map<LauncherSwipeDirection, LauncherSwipeAction>> {
  @override
  Map<LauncherSwipeDirection, LauncherSwipeAction> build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    return {
      for (final dir in LauncherSwipeDirection.values)
        dir: () {
          final stored = hive.get<String>(HiveKeys.uiStateBox, _hiveKeyFor(dir));
          // Gli swipe laterali partono disattivati (`none`) finché l'utente non
          // li imposta. Una volta impostato qualcosa (anche `none`) la chiave
          // esiste e il valore decodificato vince.
          return stored == null
              ? LauncherSwipeAction.none
              : LauncherSwipeAction.decode(stored);
        }(),
    };
  }

  Future<void> set(
    LauncherSwipeDirection dir,
    LauncherSwipeAction action,
  ) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.put(HiveKeys.uiStateBox, _hiveKeyFor(dir), action.encode());
    state = {...state, dir: action};
  }

  /// Ripristina il default della direzione (`none`) cancellando l'override
  /// utente.
  Future<void> clear(LauncherSwipeDirection dir) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.delete(HiveKeys.uiStateBox, _hiveKeyFor(dir));
    state = {...state, dir: LauncherSwipeAction.none};
  }
}

final launcherSwipeActionsProvider = NotifierProvider<
    LauncherSwipeActionsNotifier,
    Map<LauncherSwipeDirection, LauncherSwipeAction>>(
  LauncherSwipeActionsNotifier.new,
);

/// Azione corrente per una singola direzione (comodità per UI/launcher).
final swipeActionForProvider =
    Provider.family<LauncherSwipeAction, LauncherSwipeDirection>((ref, dir) {
  return ref.watch(launcherSwipeActionsProvider)[dir] ?? LauncherSwipeAction.none;
});

/// Insieme dei package "distraenti" da escludere dal picker degli swipe:
/// app targetate da QUALSIASI profilo in modalità blocklist (relation
/// `isEnabled`) + app con un limite giornaliero impostato.
///
/// Definizione volutamente stabile (non dipende dal profilo attivo in questo
/// momento): rappresenta le app che l'utente ha già marcato come problematiche,
/// così uno swipe non può aprire un'app che mostrerebbe subito l'overlay.
/// `.valueOrNull` evita di bloccare il picker durante il loading dei provider.
final distractingAppsProvider = Provider<Set<String>>((ref) {
  final profiles = ref.watch(profilesProvider).valueOrNull ?? const [];
  final limits = ref.watch(appLimitsProvider).valueOrNull ?? const {};

  final result = <String>{};
  for (final profile in profiles) {
    if (profile.blockingMode != BlockingMode.blocklist) continue;
    for (final relation in profile.apps) {
      if (relation.isEnabled) result.add(relation.packageName);
    }
  }
  result.addAll(limits.keys);
  return result;
});
