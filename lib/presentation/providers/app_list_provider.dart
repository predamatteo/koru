import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';

/// Lista completa di app installate (caricata una volta dal native).
final installedAppsProvider = FutureProvider<List<InstalledAppInfo>>((ref) async {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getInstalledApps();
});

/// Query di ricerca corrente nella drawer bar.
final appSearchQueryProvider = StateProvider<String>((_) => '');

/// App filtrate per la query corrente, ordinate per label.
final filteredAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final apps = ref.watch(installedAppsProvider).valueOrNull ?? const [];
  final query = ref.watch(appSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return apps;
  return apps.where((a) => a.label.toLowerCase().contains(query)).toList(growable: false);
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
