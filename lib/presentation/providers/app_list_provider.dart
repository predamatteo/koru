import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';
import 'app_personalization_provider.dart';

/// Lista completa di app installate (caricata una volta dal native).
final installedAppsProvider = FutureProvider<List<InstalledAppInfo>>((ref) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getInstalledApps();
});

/// Query di ricerca corrente nella drawer bar.
final appSearchQueryProvider = StateProvider<String>((_) => '');

/// App filtrate per la query + personalization (rinominate con nome
/// custom, hidden escluse dal drawer). Le app rinominate sono ricercate
/// sia per label originale sia per nome custom.
final filteredAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final apps = ref.watch(installedAppsProvider).valueOrNull ?? const [];
  final query = ref.watch(appSearchQueryProvider).trim().toLowerCase();
  final personalization = ref.watch(appPersonalizationProvider);

  final visible = apps.where((a) => !personalization.isHidden(a.packageName));

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
