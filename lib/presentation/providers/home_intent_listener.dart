import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Ascolta il canale `com.koru/navigation` popolato da MainActivity per due
/// casi:
/// - `goToLauncher`: nuovo HOME intent con Koru default launcher → porta
///   GoRouter a `/launcher` senza aspettare interazione utente.
/// - `goToHomeIfOnLauncher`: riapertura da drawer/task switcher (o HOME
///   intent mentre Koru non è più default). Se l'app è parcheggiata su
///   `/launcher` da una sessione precedente, esce verso `/home` — senza
///   quel segnale Flutter resterebbe sulla launcher UI anche quando Koru
///   non è più il launcher di sistema.
final homeIntentListenerProvider = Provider<void>((ref) {
  const channel = MethodChannel('com.koru/navigation');
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
    }
  });
  ref.onDispose(() => channel.setMethodCallHandler(null));
});
