import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';
import 'app_personalization_provider.dart';

/// Lista completa di app installate (caricata una volta dal native).
final installedAppsProvider = FutureProvider<List<InstalledAppInfo>>((ref) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getInstalledApps();
});

/// Set di package installati senza label né icone. Endpoint native cheap
/// (`getInstalledPackageNames`, ~50ms) che non decoda le bitmap come fa
/// invece `getInstalledApps` (1-3s al cold start).
///
/// Esiste come provider separato perché i consumer che servono SOLO un
/// "questo package è ancora installato?" (TodayLimitsCard filter, future
/// guard simili) non devono aspettare il decode delle icone. Senza questo,
/// la card "Today's limits" mostrava per ~3s entries fantasma di app già
/// disinstallate, fino a quando `installedAppsProvider` finiva di caricare
/// e il filtro UI poteva applicarsi.
///
/// Invalidazione: parallela a `installedAppsProvider` — i due sono
/// fotografie consistenti dello stesso PackageManager a un istante T, e
/// devono essere rinfrescati insieme (vedi `events_refresher.dart`).
final installedPackageNamesProvider = FutureProvider<Set<String>>((ref) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  final names = await blocking.getInstalledPackageNames();
  return names.toSet();
});

/// Set di package che dichiarano un'activity HOME (sono altri launcher
/// installati: Nova, Pixel Launcher, AGM Launcher, ecc.). Usati per
/// filtrare il drawer di Koru — mostrare un altro launcher tra le app
/// confonde l'utente perché tap su Pixel Launcher non fa nulla di
/// significativo (Android lo apre come app, non come launcher).
///
/// Implementato come call diretta al `com.koru/blocking` channel senza
/// passare da `BlockingChannel` per non doverlo allargare; il backing è
/// lo stesso method channel.
final launcherPackagesProvider = FutureProvider<Set<String>>((ref) async {
  const channel = MethodChannel('com.koru/blocking');
  try {
    final raw =
        await channel.invokeListMethod<String>('getLauncherPackageNames');
    return raw?.toSet() ?? const <String>{};
  } catch (_) {
    // Se la query fallisce (channel down al boot, OEM con restrizione)
    // ritorniamo set vuoto: nessun filtro è meglio che crash.
    return const <String>{};
  }
});

/// Query di ricerca corrente nella drawer bar.
final appSearchQueryProvider = StateProvider<String>((_) => '');

/// App filtrate per la query + personalization (rinominate con nome
/// custom, hidden escluse dal drawer). Le app rinominate sono ricercate
/// sia per label originale sia per nome custom.
///
/// Filtra anche gli altri launcher installati: senza questo filtro il
/// drawer mostra Nova/Pixel Launcher/AGM e tap su quegli entry non porta
/// l'utente da nessuna parte (Android NON apre un launcher come app
/// normale, lo tratta solo come candidato HOME). Koru stessa NON viene
/// filtrata (anche se ha CATEGORY_HOME): l'utente la cerca esplicitamente.
final filteredAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  // Stale-while-revalidate: mostra la lista cached anche durante un reload
  // (invalidate da PACKAGE_*/smart-refresh). Senza `unwrapPrevious()` il
  // drawer "All apps" e i provider downstream (grouped, favorite) sarebbero
  // vuoti per 1-3s mentre `getInstalledApps` rifa lo scan PackageManager
  // con decode delle icone — perceived come blink/sfarfallio al rientro
  // home. Sul primissimo cold start (no previous) resta lista vuota.
  final apps =
      ref.watch(installedAppsProvider).unwrapPrevious().valueOrNull ?? const [];
  final query = ref.watch(appSearchQueryProvider).trim().toLowerCase();
  final personalization = ref.watch(appPersonalizationProvider);
  final launcherPkgs =
      ref.watch(launcherPackagesProvider).valueOrNull ?? const <String>{};
  // Hardcoded: il package di Koru stessa. Volutamente NON filtrato dal
  // drawer anche se compare nel set launcher (l'utente vuole poterla
  // aprire da lì se ha cambiato launcher di default).
  const koruPkg = 'com.dev.koru';

  final visible = apps.where((a) =>
      !personalization.isHidden(a.packageName) &&
      (a.packageName == koruPkg || !launcherPkgs.contains(a.packageName)));

  // Applica rename: produciamo nuovi InstalledAppInfo con label custom
  // mantenendo packageName/iconBytes, così tutto il resto della UI usa
  // la label corretta.
  final withNames = visible.map((a) {
    final custom = personalization.customName(a.packageName);
    if (custom == null) return a;
    return InstalledAppInfo(
      packageName: a.packageName,
      label: custom,
      iconBytes: a.iconBytes,
    );
  }).toList();

  if (query.isEmpty) {
    withNames.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return withNames;
  }
  final filtered = withNames
      .where((a) =>
          a.label.toLowerCase().contains(query) ||
          a.packageName.toLowerCase().contains(query))
      .toList(growable: false);
  return filtered;
});

/// App raggruppate per lettera iniziale (A-Z, # per non-alfabetiche).
final groupedAppsProvider = Provider<Map<String, List<InstalledAppInfo>>>((ref) {
  final apps = ref.watch(filteredAppsProvider);
  final groups = <String, List<InstalledAppInfo>>{};
  for (final app in apps) {
    final first = app.label.isEmpty ? '#' : app.label[0].toUpperCase();
    final key = RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
    groups.putIfAbsent(key, () => []).add(app);
  }
  final orderedKeys = groups.keys.toList()
    ..sort((a, b) => a == '#'
        ? 1
        : b == '#'
            ? -1
            : a.compareTo(b));
  return {for (final k in orderedKeys) k: groups[k]!};
});
