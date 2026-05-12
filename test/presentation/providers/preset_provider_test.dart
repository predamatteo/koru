import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/repositories/preset_repository.dart';
import 'package:koru/presentation/providers/preset_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  // PresetRepository.loadAll legge asset bundle, ServiceBinding obbligatorio.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('presetRepositoryProvider', () {
    test('returns a PresetRepository wired through the profile repo', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final repo = h.container.read(presetRepositoryProvider);
      expect(repo, isA<PresetRepository>());
    });

    test('two reads return the same instance', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final r1 = h.container.read(presetRepositoryProvider);
      final r2 = h.container.read(presetRepositoryProvider);
      expect(identical(r1, r2), isTrue);
    });
  });

  group('allPresetsProvider', () {
    test('loads the 3 bundled presets from assets', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final list = await h.container.read(allPresetsProvider.future);
      expect(list, hasLength(3));
      // Sanity: ogni preset deve avere title+emoji+colorHex.
      for (final p in list) {
        expect(p.title, isNotEmpty);
        expect(p.emoji, isNotEmpty);
        expect(p.colorHex, startsWith('#'));
        expect(p.presetId, greaterThan(0));
      }
    });
  });
}
