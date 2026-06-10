import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/service_event_channel.dart';
import '../../platform/strict_mode_channel.dart';

/// Conteggio approssimato delle "schede aperte in background" per l'icona
/// top-left del launcher: app portate in foreground dal boot (o dall'ultimo
/// reset), tracciate lato nativo via UsageStats + sincronizzate con le card
/// reali quando le recents sono aperte (OpenAppsTracker). Android non espone
/// la vera lista recents alle app di terze parti.
///
/// PUSH-FIRST: il nativo emette `OpenAppsCountEvent` a ogni cambiamento del
/// set (sync con le card, reset, uninstall) e il badge si aggiorna subito,
/// senza aspettare il pull al resume — era la lentezza percepita del badge.
/// Il fetch iniziale + gli invalidate nei punti di ritorno del launcher
/// restano come pull di riallineamento (es. dopo un process restart).
///
/// keepAlive (non-autoDispose) + lettura con `valueOrNull`
/// (stale-while-revalidate, pattern di installedAppsProvider; MAI
/// `unwrapPrevious()`): durante un refresh l'icona mostra il valore
/// precedente invece di sparire.
class OpenAppsCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final svc = ref.watch(platformChannelServiceProvider);
    final sub = svc.events.events().listen((event) {
      if (event is OpenAppsCountEvent) {
        state = AsyncData(event.count);
      }
    });
    ref.onDispose(sub.cancel);
    return svc.blocking.getOpenAppsCount();
  }
}

final openAppsCountProvider =
    AsyncNotifierProvider<OpenAppsCountNotifier, int>(OpenAppsCountNotifier.new);

/// Capability dell'icona recents del launcher: determina visibilità, badge e
/// tap (vedi `_RecentsShortcut` in launcher_home_screen.dart).
class RecentsIconCapability {
  const RecentsIconCapability({
    required this.accessibilityOn,
    required this.usageStatsOn,
    required this.strictRecentsBlocked,
  });

  final bool accessibilityOn;
  final bool usageStatsOn;
  final bool strictRecentsBlocked;

  /// Senza servizio accessibilità niente GLOBAL_ACTION_RECENTS né blocco
  /// gesture: l'icona si nasconde del tutto.
  bool get iconVisible => accessibilityOn;

  /// Senza usage stats il conteggio non è derivabile: icona senza badge
  /// (resta un bottone "apri recents" funzionante).
  bool get badgeVisible => usageStatsOn;

  /// Con strict BLOCK_RECENT_APPS attivo lo strict richiuderebbe subito la
  /// schermata: icona visibile ma disabilitata (niente flash-and-kick).
  bool get tapEnabled => !strictRecentsBlocked;
}

/// One-shot (niente poll perpetuo: questo provider è keepAlive e un watch su
/// [accessibilityHealthProvider] terrebbe acceso il suo timer 5s per sempre).
/// Invalidato dagli stessi punti di [openAppsCountProvider]: se il servizio
/// accessibilità muore mentre il launcher è già visibile, l'icona si aggiorna
/// al prossimo ritorno/resume — e `openSystemRecents` è comunque difensivo
/// (ritorna false a servizio spento).
final recentsIconCapabilityProvider =
    FutureProvider<RecentsIconCapability>((ref) async {
  ref.keepAlive();
  final svc = ref.watch(platformChannelServiceProvider);
  final a11y = await svc.permission.checkAccessibilityService();
  final usage = await svc.permission.checkUsageStatsPermission();
  final mask = await svc.strictMode.getStrictModeOptions();
  return RecentsIconCapability(
    accessibilityOn: a11y,
    usageStatsOn: usage,
    strictRecentsBlocked: (mask & StrictModeOption.blockRecentApps) != 0,
  );
});
