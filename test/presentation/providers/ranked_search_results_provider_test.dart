import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';

/// Come la espone `visibleAppsProvider`: già ordinata alfabeticamente. Il
/// ranking parte da qui, e dentro ogni bucket quest'ordine deve sopravvivere.
final _apps = <InstalledAppInfo>[
  InstalledAppInfo(packageName: 'com.gallery', label: 'Gallery'),
  InstalledAppInfo(packageName: 'com.garmin.connect', label: 'Garmin Connect'),
  InstalledAppInfo(packageName: 'com.instagram.android', label: 'Instagram'),
  InstalledAppInfo(packageName: 'com.spotify.music', label: 'Spotify'),
];

ProviderContainer _container(String query) {
  final c = ProviderContainer(
    overrides: [
      // La lista base arriva già ordinata alfabeticamente da
      // `visibleAppsProvider`: qui la sostituiamo per isolare il ranking.
      visibleAppsProvider.overrideWithValue(_apps),
    ],
  );
  c.read(appSearchQueryProvider.notifier).state = query;
  return c;
}

List<String> _labels(ProviderContainer c) =>
    c.read(rankedSearchResultsProvider).map((r) => r.app.label).toList();

void main() {
  group('rankedSearchResultsProvider', () {
    test('an empty query produces no results (the drawer stays in browse mode)',
        () {
      final c = _container('   ');
      addTearDown(c.dispose);

      expect(c.read(rankedSearchResultsProvider), isEmpty);
    });

    test('labels that START with the query come before those that contain it',
        () {
      // "in" → Instagram inizia con la query, Garmin Connect la contiene a
      // metà. La rilevanza scavalca l'alfabeto: G verrebbe prima di I.
      final c = _container('in');
      addTearDown(c.dispose);

      expect(_labels(c), ['Instagram', 'Garmin Connect']);
    });

    test('alphabetical order survives inside each rank bucket', () {
      // Entrambe iniziano con "ga": nessuna delle due ha priorità di rango,
      // quindi resta l'ordine della lista base.
      final c = _container('ga');
      addTearDown(c.dispose);

      expect(_labels(c), ['Gallery', 'Garmin Connect']);
    });

    test('the match interval indexes the ORIGINAL label, not the lowercased one',
        () {
      final c = _container('nstag');
      addTearDown(c.dispose);

      final match = c.read(rankedSearchResultsProvider).single;
      expect(match.app.label, 'Instagram');
      expect(match.hasMatch, isTrue);
      final highlighted = match.app.label
          .substring(match.matchStart, match.matchStart + match.matchLength);
      expect(highlighted, 'nstag');
    });

    test('a package-only match is listed last and has nothing to highlight', () {
      // "music" compare solo in com.spotify.music, non nella label "Spotify".
      final c = _container('music');
      addTearDown(c.dispose);

      final results = c.read(rankedSearchResultsProvider);
      expect(results.map((r) => r.app.label), ['Spotify']);
      expect(results.single.hasMatch, isFalse);
    });

    test('the search is case-insensitive', () {
      final c = _container('SPOT');
      addTearDown(c.dispose);

      expect(_labels(c), ['Spotify']);
      expect(c.read(rankedSearchResultsProvider).single.matchStart, 0);
    });

    test('a query matching nothing yields an empty list, not the full inventory',
        () {
      final c = _container('zzzz');
      addTearDown(c.dispose);

      expect(c.read(rankedSearchResultsProvider), isEmpty);
    });
  });
}
