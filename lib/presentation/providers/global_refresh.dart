import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accessibility_health_provider.dart';
import 'achievements_provider.dart';
import 'active_profile_provider.dart';
import 'app_limits_provider.dart';
import 'app_list_provider.dart';
import 'favorites_provider.dart';
import 'journal_provider.dart';
import 'mood_provider.dart';
import 'notification_filter_provider.dart';
import 'preset_provider.dart';
import 'profile_providers.dart';
import 'screen_time_provider.dart';
import 'statistics_providers.dart';

/// Tutti i provider "sorgente di dati" che il pull-to-refresh deve
/// rinfrescare on-demand.
///
/// Questi sono i provider che leggono da una fonte ESTERNA al frame Dart
/// (PackageManager nativo, UsageStatsManager, file JSON cross-process letti
/// dal processo `:accessibility`, SQLite scritto anche dal native, secure
/// settings di sistema). Sono esattamente quelli che possono "freezarsi":
///   - il servizio nativo scrive su SQLite bypassando `Drift.watch`;
///   - l'EventChannel è in pausa mentre Koru è in background, quindi gli
///     eventi emessi dal processo `:accessibility` si perdono;
///   - permessi/usage del device cambiano nelle Impostazioni di sistema
///     senza notificare l'app.
///
/// NON sono inclusi di proposito:
///   - lo STATO UI ([selectedPeriodProvider], [appSearchQueryProvider]):
///     resettarli su un pull cancellerebbe la scelta dell'utente;
///   - le IMPOSTAZIONI puramente locali (monochrome, font, personalizzazione
///     app, scorciatoie launcher): nessun writer esterno le tocca, quindi
///     non si "freezano" mai e invalidarle causerebbe solo flicker;
///   - i provider DERIVATI (`filteredAppsProvider`, `topAppsByUsageProvider`,
///     `periodScreenTimeMsProvider`, ...): ricomputano da soli quando la loro
///     sorgente viene invalidata;
///   - i servizi/repository/DAO singleton e i listener di eventi.
///
/// Le `family` vengono invalidate per intero (tutte le istanze).
final List<ProviderOrFamily> _koruDataProviders = [
  // ── Inventario app installate (PackageManager nativo) ──────────────────
  installedAppsProvider,
  installedPackageNamesProvider,
  launcherPackagesProvider,

  // ── Limiti app & utilizzo giornaliero (nativo) ─────────────────────────
  appLimitsProvider,
  usageTodayMinutesProvider,
  bypassCountTodayProvider,

  // ── Statistiche di blocco/focus (stream SQLite, scritti anche dal native)
  blockTriggeredCountProvider,
  blockSkippedCountProvider,
  perAppBreakdownProvider,
  topIntentionsProvider,
  focusTimeMsProvider,

  // ── Screen time (UsageStatsManager nativo) ─────────────────────────────
  periodUsageProvider,
  previousPeriodScreenTimeMsProvider,

  // ── Profili (SQLite) ───────────────────────────────────────────────────
  profilesProvider,
  activeProfilesProvider,

  // ── Preset ─────────────────────────────────────────────────────────────
  allPresetsProvider,

  // ── Filtro notifiche & accesso (file JSON nativo + permesso di sistema) ─
  notificationFilterProvider,
  notificationAccessGrantedProvider,

  // ── Mood & journal (SQLite) ────────────────────────────────────────────
  todayMoodProvider,
  todayJournalProvider,
  allJournalsProvider,

  // ── Achievement & streak (SQLite) ──────────────────────────────────────
  streakSnapshotProvider,
  unlockedAchievementIdsProvider,
  achievementStatsProvider,

  // ── Preferiti del launcher (SQLite) ────────────────────────────────────
  favoritesProvider,

  // ── Salute del servizio di accessibilità (secure setting di sistema) ───
  accessibilityHealthProvider,
];

/// Invalida tutti i provider di dati elencati in [_koruDataProviders].
///
/// I provider attualmente osservati ricaricano subito; grazie allo
/// stale-while-revalidate (`valueOrNull` / `skipLoadingOnReload` lato UI) il
/// vecchio valore resta visibile finché non arriva il nuovo, quindi nessun
/// flicker. I provider non montati restano marcati stale e si ricaricano
/// pigramente alla prossima visita — non paghiamo scansioni native costose
/// per schermate non visibili.
void invalidateAllKoruData(WidgetRef ref) {
  for (final provider in _koruDataProviders) {
    ref.invalidate(provider);
  }
}

/// Handler per [RefreshIndicator.onRefresh]: invalida tutti i dati e tiene
/// lo spinner visibile per una durata minima così il gesto ha un feedback
/// percepibile anche quando il reload è quasi istantaneo. I dati si
/// aggiornano reattivamente man mano che i singoli provider ricompletano.
Future<void> refreshAllKoruData(WidgetRef ref) async {
  invalidateAllKoruData(ref);
  await Future<void>.delayed(const Duration(milliseconds: 450));
}
