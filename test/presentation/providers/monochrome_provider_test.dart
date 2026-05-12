import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/presentation/providers/monochrome_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('MonochromeNotifier', () {
    test('build() reads monochromeEnabled from hive settingsBox', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getBool(
            HiveKeys.settingsBox,
            HiveKeys.monochromeEnabled,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(true);

      expect(h.container.read(monochromeProvider), isTrue);
    });

    test('build() defaults to false', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getBool(
            HiveKeys.settingsBox,
            HiveKeys.monochromeEnabled,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(false);

      expect(h.container.read(monochromeProvider), isFalse);
    });

    test('setEnabled(true) persists and updates state', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getBool(
            HiveKeys.settingsBox,
            HiveKeys.monochromeEnabled,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(false);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      expect(h.container.read(monochromeProvider), isFalse);
      await h.container.read(monochromeProvider.notifier).setEnabled(true);
      expect(h.container.read(monochromeProvider), isTrue);

      verify(() => h.hive.put(
            HiveKeys.settingsBox,
            HiveKeys.monochromeEnabled,
            true,
          )).called(1);
    });

    test('toggle() flips state', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getBool(
            HiveKeys.settingsBox,
            HiveKeys.monochromeEnabled,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn(false);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      // false → true.
      await h.container.read(monochromeProvider.notifier).toggle();
      expect(h.container.read(monochromeProvider), isTrue);
      // true → false.
      await h.container.read(monochromeProvider.notifier).toggle();
      expect(h.container.read(monochromeProvider), isFalse);

      verify(() => h.hive.put(
            HiveKeys.settingsBox,
            HiveKeys.monochromeEnabled,
            any(),
          )).called(2);
    });
  });
}
