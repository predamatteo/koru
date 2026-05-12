import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/presentation/providers/app_personalization_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, String>{});
  });

  group('AppPersonalization (value object)', () {
    test('default has no hidden/renamed', () {
      const p = AppPersonalization();
      expect(p.hidden, isEmpty);
      expect(p.renamed, isEmpty);
      expect(p.isHidden('any'), isFalse);
      expect(p.customName('any'), isNull);
    });

    test('isHidden / customName reflect the configured maps', () {
      const p = AppPersonalization(
        hidden: {'com.x'},
        renamed: {'com.y': 'Chat'},
      );
      expect(p.isHidden('com.x'), isTrue);
      expect(p.isHidden('com.y'), isFalse);
      expect(p.customName('com.y'), 'Chat');
      expect(p.customName('com.x'), isNull);
    });
  });

  group('AppPersonalizationNotifier.build', () {
    test('returns empty when hive is empty', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(
            HiveKeys.hiddenAppsBox,
            HiveKeys.hiddenApps,
          )).thenReturn(const <String>[]);
      when(() => h.hive.get<Map<dynamic, dynamic>>(
            HiveKeys.hiddenAppsBox,
            HiveKeys.renamedApps,
          )).thenReturn(null);

      final p = h.container.read(appPersonalizationProvider);
      expect(p.hidden, isEmpty);
      expect(p.renamed, isEmpty);
    });

    test('loads hidden list and renamed map from hive', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(
            HiveKeys.hiddenAppsBox,
            HiveKeys.hiddenApps,
          )).thenReturn(['com.a', 'com.b']);
      when(() => h.hive.get<Map<dynamic, dynamic>>(
            HiveKeys.hiddenAppsBox,
            HiveKeys.renamedApps,
          )).thenReturn(<String, String>{'com.c': 'Chat'});

      final p = h.container.read(appPersonalizationProvider);
      expect(p.hidden, {'com.a', 'com.b'});
      expect(p.renamed, {'com.c': 'Chat'});
    });

    test('skips renamed entries where key/value are not String', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(
            HiveKeys.hiddenAppsBox,
            HiveKeys.hiddenApps,
          )).thenReturn(const <String>[]);
      when(() => h.hive.get<Map<dynamic, dynamic>>(
            HiveKeys.hiddenAppsBox,
            HiveKeys.renamedApps,
          )).thenReturn(<dynamic, dynamic>{
        'good': 'ok',
        42: 'bad-key',
        'bad-value': 99,
      });

      final p = h.container.read(appPersonalizationProvider);
      expect(p.renamed, {'good': 'ok'});
    });
  });

  group('AppPersonalizationNotifier mutations', () {
    test('toggleHidden adds a package not present', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);
      when(() => h.hive.get<Map<dynamic, dynamic>>(any(), any()))
          .thenReturn(null);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier =
          h.container.read(appPersonalizationProvider.notifier);
      await notifier.toggleHidden('com.x');

      expect(
        h.container.read(appPersonalizationProvider).hidden,
        {'com.x'},
      );
      verify(() => h.hive.setStringList(
            HiveKeys.hiddenAppsBox,
            HiveKeys.hiddenApps,
            ['com.x'],
          )).called(1);
    });

    test('toggleHidden removes a package already hidden', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(['com.x']);
      when(() => h.hive.get<Map<dynamic, dynamic>>(any(), any()))
          .thenReturn(null);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier =
          h.container.read(appPersonalizationProvider.notifier);
      expect(
        h.container.read(appPersonalizationProvider).hidden,
        {'com.x'},
      );

      await notifier.toggleHidden('com.x');
      expect(
        h.container.read(appPersonalizationProvider).hidden,
        isEmpty,
      );
      verify(() => h.hive.setStringList(
            HiveKeys.hiddenAppsBox,
            HiveKeys.hiddenApps,
            const <String>[],
          )).called(1);
    });

    test('rename sets and persists a custom name (trimmed)', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);
      when(() => h.hive.get<Map<dynamic, dynamic>>(any(), any()))
          .thenReturn(null);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      final notifier =
          h.container.read(appPersonalizationProvider.notifier);
      await notifier.rename('com.y', '  Chat  ');

      expect(
        h.container.read(appPersonalizationProvider).customName('com.y'),
        'Chat',
      );
      // L'API put accetta dynamic; verify che il valore sia la mappa.
      verify(() => h.hive.put(
            HiveKeys.hiddenAppsBox,
            HiveKeys.renamedApps,
            {'com.y': 'Chat'},
          )).called(1);
    });

    test('rename with null/empty removes the entry', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);
      when(() => h.hive.get<Map<dynamic, dynamic>>(any(), any()))
          .thenReturn(<String, String>{'com.y': 'Chat'});
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      final notifier =
          h.container.read(appPersonalizationProvider.notifier);
      // Stato iniziale: mapping già presente.
      expect(
        h.container.read(appPersonalizationProvider).customName('com.y'),
        'Chat',
      );

      await notifier.rename('com.y', '');
      expect(
        h.container.read(appPersonalizationProvider).customName('com.y'),
        isNull,
      );

      await notifier.rename('com.y', null);
      expect(
        h.container.read(appPersonalizationProvider).customName('com.y'),
        isNull,
      );
    });

    test('clearAll resets both maps and persists empty values', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(['com.a']);
      when(() => h.hive.get<Map<dynamic, dynamic>>(any(), any()))
          .thenReturn(<String, String>{'com.b': 'Bee'});
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      final notifier =
          h.container.read(appPersonalizationProvider.notifier);
      expect(
        h.container.read(appPersonalizationProvider).hidden,
        {'com.a'},
      );

      await notifier.clearAll();
      final state = h.container.read(appPersonalizationProvider);
      expect(state.hidden, isEmpty);
      expect(state.renamed, isEmpty);

      verify(() => h.hive.setStringList(
            HiveKeys.hiddenAppsBox,
            HiveKeys.hiddenApps,
            const <String>[],
          )).called(1);
      verify(() => h.hive.put(
            HiveKeys.hiddenAppsBox,
            HiveKeys.renamedApps,
            <String, String>{},
          )).called(1);
    });
  });
}
