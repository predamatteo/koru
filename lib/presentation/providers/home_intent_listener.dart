import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Ascolta il canale `com.koru/navigation` popolato da MainActivity per:
/// - `goToLauncher`: nuovo HOME intent con Koru default launcher → porta
///   GoRouter a `/launcher` senza aspettare interazione utente.
/// - `goToHomeIfOnLauncher`: riapertura da drawer/task switcher (o HOME
///   intent mentre Koru non è più default). Se l'app è parcheggiata su
///   `/launcher` da una sessione precedente, esce verso `/home` — senza
///   quel segnale Flutter resterebbe sulla launcher UI anche quando Koru
///   non è più il launcher di sistema.
/// - `requireBackdoorCode` (SEC-12): l'utente sta tentando di disabilitare il
///   device admin con strict mode attivo → apriamo il prompt del backdoor code.
///
/// SEC-12 cold start: se MainActivity è stata lanciata da
/// `KoruDeviceAdminReceiver.onDisableRequested` PRIMA che questo handler fosse
/// registrato, il native non ha potuto fare push del metodo. Per non perdere
/// l'evento, alla registrazione facciamo PULL via `consumePendingBackdoorPrompt`
/// e, se pendente, navighiamo al prompt.
final homeIntentListenerProvider = Provider<void>((ref) {
  // keepAlive: il listener deve restare registrato per tutta la vita dell'app
  // perché MainActivity può inviare `goToLauncher` / `goToHomeIfOnLauncher`
  // in qualsiasi momento (es. HOME intent ricevuto mentre Koru è in
  // background). Senza keepAlive, se nessuna UI lo watcha (provider listener
  // smontati durante deep navigation), Riverpod lo disposerebbe e i futuri
  // intent verrebbero persi finché non si rimonta un consumer.
  ref.keepAlive();
  const channel = MethodChannel('com.koru/navigation');

  /// SEC-12: porta l'utente al prompt del backdoor code. `push` (non `go`) così
  /// la schermata si sovrappone e, una volta sbloccato/annullato, si torna dove
  /// si era. Idempotente sull'eventuale doppia notifica (push+pull).
  void openBackdoorPrompt() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    const backdoorRoute = '${KoruRoutes.settings}/backdoor';
    final router = GoRouter.of(ctx);
    final loc = router.routerDelegate.currentConfiguration.uri.toString();
    if (loc == backdoorRoute) return; // già lì: non impilare due volte
    ctx.push(backdoorRoute);
  }

  channel.setMethodCallHandler((call) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    switch (call.method) {
      case 'goToLauncher':
        ctx.go(KoruRoutes.launcher);
        break;
      case 'goToHomeIfOnLauncher':
        final router = GoRouter.of(ctx);
        final loc =
            router.routerDelegate.currentConfiguration.uri.toString();
        if (loc == KoruRoutes.launcher ||
            loc.startsWith('${KoruRoutes.launcher}/')) {
          ctx.go(KoruRoutes.home);
        }
        break;
      case 'requireBackdoorCode': // SEC-12 (push dal native, app già viva)
        openBackdoorPrompt();
        break;
    }
  });

  // SEC-12 cold start: subito dopo la registrazione dell'handler, chiediamo al
  // native se c'è un prompt backdoor in sospeso (lanciato prima che fossimo
  // pronti) e in tal caso lo apriamo. Differiamo a dopo il primo frame: al
  // cold start il rootNavigator potrebbe non avere ancora un context.
  Future<void> drainPendingBackdoor() async {
    try {
      final pending =
          await channel.invokeMethod<bool>('consumePendingBackdoorPrompt');
      if (pending == true) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => openBackdoorPrompt());
      }
    } catch (_) {
      // Canale non pronto / metodo non implementato: nessun pending da drenare.
    }
  }

  drainPendingBackdoor();

  ref.onDispose(() => channel.setMethodCallHandler(null));
});
