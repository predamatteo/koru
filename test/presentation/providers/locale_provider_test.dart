import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/core/constants/koru_locale.dart';
import 'package:koru/presentation/providers/locale_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('localePreferenceProvider', () {
    test('defaults to system when Hive has never been written', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('');

      expect(h.container.read(localePreferenceProvider), KoruLocale.system);
    });

    test('reads the persisted language back', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('it');

      expect(h.container.read(localePreferenceProvider), KoruLocale.italian);
    });

    test('an unrecognised stored value degrades to system', () {
      // Una lingua rimossa da una versione futura non deve impedire l'avvio.
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('klingon');

      expect(h.container.read(localePreferenceProvider), KoruLocale.system);
    });

    test('set() persists the storage value and updates the state', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('');
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      await h.container
          .read(localePreferenceProvider.notifier)
          .set(KoruLocale.english);

      verify(() => h.hive.put(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            'en',
          )).called(1);
      expect(h.container.read(localePreferenceProvider), KoruLocale.english);
    });

    test('set() mirrors the choice to the native per-app locale', () async {
      // Senza questa propagazione overlay, notifiche e widget resterebbero
      // nella lingua di sistema mentre la UI Flutter cambia.
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('');
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      await h.container
          .read(localePreferenceProvider.notifier)
          .set(KoruLocale.italian);

      verify(() => h.profileCh.setAppLocale('it')).called(1);
    });

    test('choosing system clears the native override with an empty tag',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('it');
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      await h.container
          .read(localePreferenceProvider.notifier)
          .set(KoruLocale.system);

      verify(() => h.profileCh.setAppLocale('')).called(1);
    });

    test('a failing channel does not break the language change', () async {
      // Il canale è best-effort: su API < 33 è una no-op, e comunque la
      // preferenza è già stata persistita quando lo chiamiamo.
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('');
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});
      when(() => h.profileCh.setAppLocale(any()))
          .thenThrow(Exception('channel dead'));

      await expectLater(
        h.container
            .read(localePreferenceProvider.notifier)
            .set(KoruLocale.english),
        completes,
      );
      expect(h.container.read(localePreferenceProvider), KoruLocale.english);
    });

    test('syncToNative re-asserts the stored language', () async {
      // Il per-app locale è stato di SISTEMA: può divergere da Hive (cambio da
      // Impostazioni Android, restore di un backup).
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.getString(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            defaultValue: any(named: 'defaultValue'),
          )).thenReturn('it');

      await h.container.read(localePreferenceProvider.notifier).syncToNative();

      verify(() => h.profileCh.setAppLocale('it')).called(1);
    });
  });
}
