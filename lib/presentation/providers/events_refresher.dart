import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/service_event_channel.dart';
import 'app_list_provider.dart';
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

void _invalidateInstalledApps(Ref ref) {
  ref.invalidate(installedAppsProvider);
}

/// Ascolta lo stream di eventi native (BLOCKING_STATE / IN_APP_SECTION_DETECTED
/// / QUICK_BLOCK_TICK) e invalida i provider di statistiche così i conteggi
/// di Blocks e Focus time si aggiornano in real-time anche se il native
/// scrive direttamente su SQLite (bypassando il tracking di Drift.watch).
final blockingEventsRefresherProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  bool? lastTickIsActive;
  final sub = events.listen((event) {
    final shouldInvalidate = (event is BlockingStateEvent && event.isBlocking) ||
        (event is UnknownServiceEvent &&
            event.raw['type'] == 'IN_APP_SECTION_DETECTED');
    if (shouldInvalidate) {
      _invalidateStats(ref);
      return;
    }
    // Quick-block / pomodoro session finita → il native ha appena scritto
    // un focus_usage_event. Invalida le stats per aggiornare focus time.
    if (event is QuickBlockTickEvent) {
      final was = lastTickIsActive;
      lastTickIsActive = event.isActive;
      if (was == true && !event.isActive) {
        developer.log(
          'Focus session tick transition true→false, invalidating stats',
          name: 'EventsRefresher',
        );
        _invalidateStats(ref);
      }
    }
  });
  ref.onDispose(sub.cancel);
});

/// Observer di AppLifecycleState che invalida tutti i provider di
/// statistiche ogni volta che Koru torna in foreground.
///
/// Motivi multipli:
/// 1. Stats: l'EventChannel di Flutter è in pausa mentre l'app è in
///    background (es. utente su Instagram, bloccato dall'overlay e tornato
///    alla home). Gli eventi di blocking emessi dal processo :accessibility
///    durante quel periodo si perdono, quindi affidiamoci al segnale
///    affidabile dell'app che rientra in foreground.
/// 2. Lista app installate: il [PackageEventsReceiver] nativo è registrato
///    in MainActivity.onStart() e deregistrato in onStop(). Quando Koru è
///    il launcher e l'utente apre un'altra app (o anche solo trascina giù
///    la notification shade) l'activity va in onStop e perde i broadcast
///    PACKAGE_ADDED/REMOVED/REPLACED che arrivano in quel periodo. Al
///    rientro in foreground rinfreschiamo comunque la lista così launcher
///    e all-apps drawer sono sempre coerenti col PackageManager.
final appLifecycleInvalidatorProvider = Provider<void>((ref) {
  final binding = WidgetsBinding.instance;
  final observer = _LifecycleObserver(() {
    _invalidateStats(ref);
    _invalidateInstalledApps(ref);
  });
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

/// Ascolta i broadcast PACKAGE_ADDED / PACKAGE_REMOVED / PACKAGE_REPLACED
/// emessi dal native e invalida la lista di app installate così launcher e
/// all-apps drawer si rigenerano senza che l'utente debba riavviare Koru.
///
/// Debounce 400ms: un singolo install genera tipicamente ADDED + (eventuale)
/// REPLACED in rapida successione — basta un solo refresh.
final packageEventsRefresherProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  Timer? debounce;
  final sub = events.listen((event) {
    if (event is! PackageChangedEvent) return;
    developer.log(
      'Package ${event.kind}: ${event.packageName} — scheduling refresh',
      name: 'PackageEventsRefresher',
    );
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      ref.invalidate(installedAppsProvider);
    });
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
});
