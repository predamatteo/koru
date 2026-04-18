import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Ascolta il canale `com.koru/navigation` popolato da MainActivity quando
/// arriva un nuovo HOME intent (utente preme Home mentre Koru è in fore-
/// ground, con Koru settato come default launcher). Risposta: naviga il
/// GoRouter root a `/launcher` immediatamente così non rimane sulla
/// schermata precedente finché l'utente interagisce.
final homeIntentListenerProvider = Provider<void>((ref) {
  const channel = MethodChannel('com.koru/navigation');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'goToLauncher') {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.go(KoruRoutes.launcher);
      }
    }
  });
  ref.onDispose(() => channel.setMethodCallHandler(null));
});
