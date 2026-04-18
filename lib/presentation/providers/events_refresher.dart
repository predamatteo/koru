import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/service_event_channel.dart';
import 'mood_provider.dart';
import 'profile_providers.dart';
import 'statistics_providers.dart';

void _invalidateStats(Ref ref) {
  ref.invalidate(blockTriggeredCountProvider);
  ref.invalidate(blockSkippedCountProvider);
  ref.invalidate(perAppBreakdownProvider);
  ref.invalidate(topIntentionsProvider);
  ref.invalidate(focusTimeMsProvider);
  ref.invalidate(todayMoodProvider);
  ref.invalidate(profilesProvider);
}

/// Ascolta lo stream di eventi native (BLOCKING_STATE / IN_APP_SECTION_DETECTED)
/// e invalida i provider di statistiche così il conteggio "Blocks" si
/// aggiorna in real-time anche se il native scrive direttamente su SQLite
/// (bypassando il tracking automatico di Drift.watch).
final blockingEventsRefresherProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  final sub = events.listen((event) {
    final shouldInvalidate = (event is BlockingStateEvent && event.isBlocking) ||
        (event is UnknownServiceEvent &&
            event.raw['type'] == 'IN_APP_SECTION_DETECTED');
    if (shouldInvalidate) _invalidateStats(ref);
  });
  ref.onDispose(sub.cancel);
});

/// Observer di AppLifecycleState che invalida tutti i provider di
/// statistiche ogni volta che Koru torna in foreground.
///
/// Motivo: l'EventChannel di Flutter è in pausa mentre l'app è in
/// background (es. utente su Instagram, bloccato dall'overlay e tornato
/// alla home). Gli eventi di blocking emessi dal processo :accessibility
/// durante quel periodo si perdono, quindi affidiamoci al segnale
/// affidabile dell'app che rientra in foreground.
final appLifecycleInvalidatorProvider = Provider<void>((ref) {
  final binding = WidgetsBinding.instance;
  final observer = _LifecycleObserver(() => _invalidateStats(ref));
  binding.addObserver(observer);
  ref.onDispose(() => binding.removeObserver(observer));
});

class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
