import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/core/constants/koru_locale.dart';
import 'package:koru/core/di/providers.dart';
import 'package:koru/presentation/providers/locale_provider.dart';
import 'package:koru/presentation/screens/settings/sub_screens/language_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_helpers/provider_test_utils.dart';
import '../../../_helpers/widget_test_utils.dart';

void main() {
  /// Il picker legge Hive e scrive sul canale nativo: entrambi mockati.
  TestHarness harnessWith(String stored) {
    final h = buildTestContainer();
    when(() => h.hive.getString(
          HiveKeys.settingsBox,
          HiveKeys.localeCode,
          defaultValue: any(named: 'defaultValue'),
        )).thenReturn(stored);
    when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});
    return h;
  }

  group('LanguageScreen', () {
    testWidgets('lists system default plus every supported language',
        (tester) async {
      final h = harnessWith('');
      addTearDown(h.dispose);

      await pumpKoruWidget(
        tester,
        const LanguageScreen(),
        overrides: [
          hiveSettingsServiceProvider.overrideWithValue(h.hive),
          platformChannelServiceProvider.overrideWithValue(h.platform),
        ],
      );

      expect(find.text('System default'), findsOneWidget);
      // I nomi delle lingue restano endonimi: chi apre questa schermata per
      // uscire da una lingua che non legge deve riconoscere la propria.
      expect(find.text('Italiano'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('preselects the persisted language', (tester) async {
      final h = harnessWith('it');
      addTearDown(h.dispose);

      await pumpKoruWidget(
        tester,
        const LanguageScreen(),
        overrides: [
          hiveSettingsServiceProvider.overrideWithValue(h.hive),
          platformChannelServiceProvider.overrideWithValue(h.platform),
        ],
      );

      final selected = tester
          .widgetList<RadioListTile<KoruLocale>>(
            find.byType(RadioListTile<KoruLocale>),
          )
          .where((t) => t.value == KoruLocale.italian);
      expect(selected, hasLength(1));
      expect(
        tester
            .widget<RadioGroup<KoruLocale>>(find.byType(RadioGroup<KoruLocale>))
            .groupValue,
        KoruLocale.italian,
      );
    });

    testWidgets('tapping a language persists it and tells the native side',
        (tester) async {
      final h = harnessWith('');
      addTearDown(h.dispose);

      await pumpKoruWidget(
        tester,
        const LanguageScreen(),
        overrides: [
          hiveSettingsServiceProvider.overrideWithValue(h.hive),
          platformChannelServiceProvider.overrideWithValue(h.platform),
        ],
      );

      await tester.tap(find.text('Italiano'));
      await tester.pumpAndSettle();

      verify(() => h.hive.put(
            HiveKeys.settingsBox,
            HiveKeys.localeCode,
            'it',
          )).called(1);
      verify(() => h.profileCh.setAppLocale('it')).called(1);
    });

    testWidgets('the screen itself is translated', (tester) async {
      final h = harnessWith('');
      addTearDown(h.dispose);

      await pumpKoruWidget(
        tester,
        const LanguageScreen(),
        locale: const Locale('it'),
        overrides: [
          hiveSettingsServiceProvider.overrideWithValue(h.hive),
          platformChannelServiceProvider.overrideWithValue(h.platform),
        ],
      );

      expect(find.text('Lingua'), findsOneWidget);
      expect(find.text('Predefinita di sistema'), findsOneWidget);
      expect(find.text('System default'), findsNothing);
    });
  });

  group('locale wiring', () {
    testWidgets('KoruLocale.locale is what MaterialApp needs', (tester) async {
      // Il contratto vero è questo: `system` ⇒ `locale: null` ⇒ Flutter
      // risolve sul sistema. Un valore non-null lì dentro bloccherebbe la UI
      // su una lingua a prescindere dal telefono.
      final h = harnessWith('');
      addTearDown(h.dispose);

      expect(
        h.container.read(localePreferenceProvider).locale,
        isNull,
      );
    });
  });
}
