import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/diagnostics/funnel_milestones.dart';

/// Stato del servizio di accessibilità Koru, ripollato periodicamente
/// finché un consumer (es. il banner in home) è montato.
///
/// Perché un poll attivo: ColorOS/MIUI/EMUI killano in autonomia gli
/// AccessibilityService quando il battery manager classifica il processo
/// come "abuser". Dopo N crash o N kill, il sistema rimuove il servizio
/// da `enabled_accessibility_services` *senza notificare l'app*. Senza un
/// poll periodico l'utente non se ne accorge finché non prova a fare
/// qualcosa che dipende dal blocco (es. apre un'app limitata).
///
/// Pattern allineato a minimalist_phone (vedi r3/K0.java:60): legge la
/// stessa secure-setting e la espone come stream osservabile.
///
/// Cadenza: 5s. Il check è una syscall locale (AccessibilityManager),
/// nessun overhead network. Lifecycle-aware: `keepAlive` non e' settato
/// quindi quando nessuno lo osserva il timer si spegne.
final accessibilityHealthProvider = StreamProvider.autoDispose<bool>((ref) {
  final channel = ref.watch(platformChannelServiceProvider).permission;
  final controller = StreamController<bool>();

  Future<void> tick() async {
    if (controller.isClosed) return;
    try {
      final ok = await channel.checkAccessibilityService();
      if (!controller.isClosed) controller.add(ok);
      // Funnel milestone locale (write-once), best-effort e ISOLATO: l'add di
      // `ok` e' gia' avvenuto, e _markOnce non rilancia — cosi' un errore del
      // funnel non puo' mai alterare lo stream di health.
      if (ok) {
        FunnelMilestones.markAccessibilityGranted(
          ref.read(hiveSettingsServiceProvider),
        );
      }
    } catch (_) {
      if (!controller.isClosed) controller.add(false);
    }
  }

  // Primo check immediato così il banner non lampeggia in caricamento.
  tick();
  // Poll: 5s e' un buon compromesso fra reattivita' (utente vede il
  // banner entro pochi secondi dal kill) e batteria (12 syscall/min).
  final timer = Timer.periodic(const Duration(seconds: 5), (_) => tick());

  // Re-check immediato quando la app torna in foreground: copre il caso
  // utente esce per andare nelle Settings, riabilita, torna a Koru.
  // Senza questo, il banner resterebbe acceso fino al prossimo tick.
  final lifecycleObserver = _AccessibilityLifecycleObserver(tick);
  WidgetsBinding.instance.addObserver(lifecycleObserver);

  ref.onDispose(() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(lifecycleObserver);
    controller.close();
  });

  return controller.stream;
});

class _AccessibilityLifecycleObserver with WidgetsBindingObserver {
  _AccessibilityLifecycleObserver(this._onResume);

  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}
