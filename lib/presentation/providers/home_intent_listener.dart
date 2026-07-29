import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../domain/entities/statistics_period.dart';
import 'global_refresh.dart';
import 'screen_time_provider.dart';
import 'statistics_providers.dart';

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

  const backdoorRoute = '${KoruRoutes.settings}/backdoor';

  String currentLocation(BuildContext ctx) =>
      GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.toString();

  /// SEC-12: porta l'utente al prompt del backdoor code. `push` (non `go`) così
  /// la schermata si sovrappone e, una volta sbloccato/annullato, si torna dove
  /// si era. Idempotente sull'eventuale doppia notifica (push+pull).
  void openBackdoorPrompt() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    if (currentLocation(ctx) == backdoorRoute) return; // già lì: non impilare
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
        final loc = currentLocation(ctx);
        if (loc == KoruRoutes.launcher ||
            loc.startsWith('${KoruRoutes.launcher}/')) {
          ctx.go(KoruRoutes.home);
        }
        break;
      case 'requireBackdoorCode': // SEC-12 (push dal native, app già viva)
        openBackdoorPrompt();
        break;
      case 'goToRoute':
        // Tap sul widget home (app già viva). La route arriva dal native, che
        // l'ha già validata contro l'allowlist di MainActivity.widgetRoute;
        // qui ci limitiamo a rifiutare valori non-stringa o vuoti per non
        // passare spazzatura a GoRouter.
        final route = call.arguments;
        if (route is! String || !route.startsWith('/')) break;
        // SEC-12: MainActivity è exported, quindi un'app terza può ricostruire
        // l'intent del widget. La route è ristretta a `/stats` e non può quindi
        // portare da nessuna parte di sensibile, MA una `go` cancellerebbe il
        // prompt del backdoor code se fosse aperto in quel momento —
        // trasformando il deterrent in qualcosa che si può far sparire
        // dall'esterno. Se siamo sul prompt, la navigazione non passa.
        if (currentLocation(ctx) == backdoorRoute) break;
        if (route != KoruRoutes.stats) {
          ctx.go(route);
          break;
        }
        // Il widget è etichettato "OGGI" e mostra sempre [mezzanotte, ora].
        // `selectedPeriodProvider` e `selectedStatsDayProvider` sono stato UI
        // che sopravvive alla navigazione: senza reset, un utente che aveva
        // lasciato le statistiche su "This week" (o su un giorno del grafico)
        // toccherebbe un widget che dice 3h 12m e atterrerebbe su una
        // schermata che ne mostra 19h — stesso dato, due numeri.
        ref.read(selectedPeriodProvider.notifier).state =
            StatisticsPeriod.today;
        ref.read(selectedStatsDayProvider.notifier).state = null;
        // Stesso motivo, ma sull'asse del TEMPO: i provider Dart possono avere
        // in cache uno screen time vecchio di ore. Aggiorniamo PRIMA di aprire
        // la schermata (con timeout interno), così la pagina appare già con i
        // numeri del widget invece di correggersi sotto gli occhi dell'utente.
        await refreshStatsScreenData(ref);
        // Post-await: il context può essere cambiato o sparito, e il prompt
        // del backdoor code potrebbe essersi aperto nel frattempo (SEC-12).
        final target = rootNavigatorKey.currentContext;
        if (target == null || !target.mounted) break;
        if (currentLocation(target) == backdoorRoute) break;
        target.go(route);
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
