import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/diagnostics/black_box.dart';
import '../../platform/service_event_channel.dart';
import 'app_limits_provider.dart';
import 'app_list_provider.dart';
import 'mood_provider.dart';
import 'statistics_providers.dart';

void _invalidateStats(Ref ref) {
  ref.invalidate(blockTriggeredCountProvider);
  ref.invalidate(blockSkippedCountProvider);
  ref.invalidate(perAppBreakdownProvider);
  ref.invalidate(topIntentionsProvider);
  ref.invalidate(focusTimeMsProvider);
  ref.invalidate(todayMoodProvider);
  // PERF: `profilesProvider` RIMOSSO da questo set. I profili sono scritti SOLO
  // dall'UI Dart (ProfileRepository → notifyProfileChanged verso il native, mai
  // il contrario): `Drift.watch` è già reattivo, quindi né un evento di blocking
  // né un resume possono averli cambiati. Era l'unico provider qui che ricomputa
  // eagerly anche quando Koru è launcher (ha listener vivi via activeProfiles/
  // launcherSwipeActions) → re-query `watchAllProfiles` (loop N+1) sprecata ad
  // alta frequenza. Resta invalidato dal pull-to-refresh manuale (global_refresh)
  // e dalle proprie mutazioni Dart.
}

void _invalidateInstalledApps(Ref ref) {
  ref.invalidate(installedAppsProvider);
  // I due provider sono fotografie consistenti dello stesso PackageManager
  // a un istante T: se uno diventa stale lo e' anche l'altro. Senza
  // questa invalidazione il filtro di [TodayLimitsCard] continuerebbe
  // a mostrare app gia' disinstallate fra un PACKAGE_REMOVED e il
  // successivo cold start.
  ref.invalidate(installedPackageNamesProvider);
}

/// Smart refresh per [installedAppsProvider] post-resume.
///
/// `getInstalledApps()` nativo è oneroso (PackageManager scan + decode
/// di tutte le icone in PNG bytes), può prendere 1-3s su set di app
/// reali. Invalidare a tappeto ad ogni resume causa un freeze visibile
/// in qualsiasi schermo che mostri la lista (drawer, NotificationFilter,
/// ecc.) — anche se l'utente sta semplicemente tornando da Settings di
/// sistema senza aver toccato il package set.
///
/// Strategia: chiamare un endpoint nativo "cheap" che ritorna solo i
/// package names. Se il set è identico al cached, no-op. Solo quando
/// rileviamo un delta (install/uninstall avvenuto in onStop) paghiamo
/// il costo del refresh completo.
Future<void> _smartRefreshInstalledApps(Ref ref) async {
  final state = ref.read(installedAppsProvider);
  if (state.hasError) {
    // Primo load fallito (es. PackageManager scan crashato durante init,
    // o channel down al boot): senza retry esplicito il provider resta
    // sempre in AsyncError finché un altro trigger (package event) non
    // lo invalida. Forzare invalidate qui risolve il blocco al rientro
    // foreground anche dopo un fail iniziale.
    developer.log(
      'installedAppsProvider in error state at resume → force retry',
      name: 'EventsRefresher',
    );
    _invalidateInstalledApps(ref);
    return;
  }
  final cached = state.valueOrNull;
  if (cached == null) {
    // Lista mai caricata: il prossimo `ref.watch` la caricherà; nessun
    // motivo di forzare adesso.
    return;
  }
  final List<String> fresh;
  try {
    fresh = await ref
        .read(platformChannelServiceProvider)
        .blocking
        .getInstalledPackageNames();
  } catch (e) {
    // Se la query cheap fallisce (channel down al resume?), fallback
    // sicuro: invalida così il prossimo accesso ricarica.
    developer.log(
      'getInstalledPackageNames() failed: $e — fallback invalidate',
      name: 'EventsRefresher',
    );
    _invalidateInstalledApps(ref);
    return;
  }
  final cachedSet = cached.map((a) => a.packageName).toSet();
  final freshSet = fresh.toSet();
  final unchanged =
      cachedSet.length == freshSet.length && cachedSet.containsAll(freshSet);
  if (unchanged) return;
  developer.log(
    'Installed package set changed (cached=${cachedSet.length} '
    'fresh=${freshSet.length}) → invalidating installedAppsProvider',
    name: 'EventsRefresher',
  );
  _invalidateInstalledApps(ref);
  // Sweep limits per app rimosse: il diff ci dice solo CHE qualcosa
  // e' cambiato, non cosa. Passiamo il fresh set come authoritative —
  // cleanupUninstalled e' no-op se non ci sono entries stale.
  unawaited(_cleanupStaleAppLimits(ref, freshSet));
}

/// Rimuove dalle preferenze app_limits le entry per package non piu'
/// installati. Chiamata su PACKAGE_REMOVED e su resume.
Future<void> _cleanupStaleAppLimits(
  Ref ref,
  Set<String> installedPackages,
) async {
  try {
    // Forza l'inizializzazione del provider se non lo era ancora — senza
    // questo `state.valueOrNull` dentro cleanupUninstalled sarebbe null
    // e la pulizia diventerebbe no-op silenziosa al primo trigger.
    await ref.read(appLimitsProvider.future);
    await ref
        .read(appLimitsProvider.notifier)
        .cleanupUninstalled(installedPackages);
  } catch (e) {
    developer.log(
      'cleanupUninstalled failed: $e',
      name: 'EventsRefresher',
    );
  }
}

/// Ascolta lo stream di eventi native (BLOCKING_STATE / IN_APP_SECTION_DETECTED
/// / QUICK_BLOCK_TICK) e invalida i provider di statistiche così i conteggi
/// di Blocks e Focus time si aggiornano in real-time anche se il native
/// scrive direttamente su SQLite (bypassando il tracking di Drift.watch).
final blockingEventsRefresherProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
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
    // Edge-driven: ascoltiamo QUICK_BLOCK_FINISHED (emesso una volta a fine
    // sessione) invece di parsare ogni tick 1Hz — vedi service_event_channel.
    if (event is QuickBlockFinishedEvent) {
      developer.log(
        'Focus session finished, invalidating stats',
        name: 'EventsRefresher',
      );
      _invalidateStats(ref);
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
  // PERF: throttle del handler di resume. Con Koru launcher di default
  // `resumed` scatta a ogni ritorno home / pull della notification shade /
  // dismissal di un overlay di blocco — anche decine di volte al minuto. Senza
  // throttle ogni resume rilancia l'invalidazione delle stats + una scansione
  // PackageManager nativa. Gli eventi di blocking emessi mentre l'app era in
  // background arrivano comunque al rientro via il singolo upstream affidabile
  // dell'EventChannel (service_event_channel.dart), quindi l'invalidate-su-resume
  // resta solo un catch-up periodico: 1 ogni 45s è più che sufficiente.
  const minResumeGap = Duration(seconds: 45);
  DateTime? lastHandledResume;
  var resumeCount = 0; // diagnostica Fase 3 (solo debug)
  final observer = _LifecycleObserver(() {
    resumeCount++;
    final now = DateTime.now();
    final last = lastHandledResume;
    if (last != null && now.difference(last) < minResumeGap) {
      if (kDebugMode) {
        debugPrint(
          'KoruPerf.resume #$resumeCount THROTTLED (gap<45s, nessuna invalidazione)',
        );
      }
      BlackBox.log('RESUME', '#$resumeCount THROTTLED (gap<45s, nessuna invalidazione)');
      return;
    }
    lastHandledResume = now;
    if (kDebugMode) {
      debugPrint(
        'KoruPerf.resume #$resumeCount HANDLED -> invalidate stats + smart refresh',
      );
    }
    BlackBox.log('RESUME', '#$resumeCount HANDLED -> invalidate stats + smart refresh installedApps');
    _invalidateStats(ref);
    // Fire-and-forget: il diff-based refresh è async e non deve bloccare
    // il frame di rientro nell'app.
    unawaited(_smartRefreshInstalledApps(ref));
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
    // Cleanup immediato del limit per il pkg rimosso: indipendente dal
    // debounce della lista app (per il quale aspettiamo 400ms per
    // coalescere ADDED+REPLACED). Il limit cleanup non beneficia del
    // batching e prima viene rimossa la entry meglio e' (UI fantasma).
    if (event.kind == 'removed') {
      unawaited(
        ref.read(appLimitsProvider.notifier).clear(event.packageName),
      );
    }
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      _invalidateInstalledApps(ref);
    });
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
});
