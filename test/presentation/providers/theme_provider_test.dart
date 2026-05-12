import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/core/theme/font_catalog.dart';
import 'package:koru/presentation/providers/theme_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    // Per gli stub di `put` (signature dynamic).
    registerFallbackValue(KoruFont.system);
  });

  group('FontPreferenceNotifier', () {
    test('build() reads activeFontId from hive uiStateBox and maps to KoruFont',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getInt(
            HiveKeys.uiStateBox,
            HiveKeys.activeFontId,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(KoruFont.orbitron.id);

      final font = h.container.read(fontPreferenceProvider);
      expect(font, KoruFont.orbitron);
      verify(() => h.hive.getInt(
            HiveKeys.uiStateBox,
            HiveKeys.activeFontId,
            defaultValue: any(named: 'defaultValue'),
          )).called(1);
    });

    test('build() returns KoruFont.system when stored id is 0 (default)',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getInt(
            HiveKeys.uiStateBox,
            HiveKeys.activeFontId,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(0);

      expect(h.container.read(fontPreferenceProvider), KoruFont.system);
    });

    test('build() falls back to system when stored id is unknown', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getInt(
            HiveKeys.uiStateBox,
            HiveKeys.activeFontId,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(99);

      expect(h.container.read(fontPreferenceProvider), KoruFont.system);
    });

    test('set(font) persists id to hive and updates state', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getInt(
            HiveKeys.uiStateBox,
            HiveKeys.activeFontId,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(0);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      // Force initial build.
      expect(h.container.read(fontPreferenceProvider), KoruFont.system);

      await h.container
          .read(fontPreferenceProvider.notifier)
          .set(KoruFont.goldman);

      expect(h.container.read(fontPreferenceProvider), KoruFont.goldman);
      verify(() => h.hive.put(
            HiveKeys.uiStateBox,
            HiveKeys.activeFontId,
            KoruFont.goldman.id,
          )).called(1);
    });
  });
}
