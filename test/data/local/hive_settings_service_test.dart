import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/data/local/hive_settings_service.dart';

void main() {
  group('HiveSettingsService', () {
    late Directory tempDir;
    late HiveSettingsService service;

    setUpAll(() async {
      // Hive uses dart:io paths for native boxes — point it at a fresh
      // temp dir so we don't touch the user's real Hive data.
      tempDir = await Directory.systemTemp.createTemp('koru_hive_test_');
      Hive.init(tempDir.path);
    });

    setUp(() async {
      service = HiveSettingsService();
      await service.init();
    });

    tearDown(() async {
      // Close every box so the next test starts clean.
      await Hive.deleteFromDisk();
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('init', () {
      test('opens all 6 boxes without throwing', () async {
        // service has already been init'd in setUp; just sanity-check we can
        // read/write a key on each box without an error.
        for (final box in <String>[
          HiveKeys.settingsBox,
          HiveKeys.onboardingBox,
          HiveKeys.uiStateBox,
          HiveKeys.cacheBox,
          HiveKeys.hiddenAppsBox,
          HiveKeys.quickTogglesBox,
        ]) {
          await service.put(box, 'probe', 1);
          expect(service.get<int>(box, 'probe'), 1);
        }
      });
    });

    group('put + get<T> roundtrip', () {
      test('int roundtrip', () async {
        await service.put(HiveKeys.settingsBox, 'count', 42);
        expect(service.get<int>(HiveKeys.settingsBox, 'count'), 42);
      });

      test('bool roundtrip', () async {
        await service.put(HiveKeys.settingsBox, 'flag', true);
        expect(service.get<bool>(HiveKeys.settingsBox, 'flag'), isTrue);
      });

      test('String roundtrip', () async {
        await service.put(HiveKeys.settingsBox, 'name', 'koru');
        expect(service.get<String>(HiveKeys.settingsBox, 'name'), 'koru');
      });

      test('get<T> returns null for an unknown key', () {
        expect(service.get<int>(HiveKeys.settingsBox, 'never_set'), isNull);
      });
    });

    group('typed accessors with defaults', () {
      test('getBool returns defaultValue when missing', () {
        expect(
          service.getBool(HiveKeys.onboardingBox, 'absent',
              defaultValue: true),
          isTrue,
        );
        // Default-default is false.
        expect(service.getBool(HiveKeys.onboardingBox, 'absent2'), isFalse);
      });

      test('getInt returns defaultValue when missing', () {
        expect(
          service.getInt(HiveKeys.settingsBox, 'absent', defaultValue: 99),
          99,
        );
        expect(service.getInt(HiveKeys.settingsBox, 'absent2'), 0);
      });

      test('getString returns defaultValue when missing', () {
        expect(
          service.getString(HiveKeys.settingsBox, 'absent',
              defaultValue: 'fallback'),
          'fallback',
        );
        expect(service.getString(HiveKeys.settingsBox, 'absent2'), '');
      });

      test('getBool returns the stored value when present', () async {
        await service.put(HiveKeys.onboardingBox, 'k', true);
        expect(
          service.getBool(HiveKeys.onboardingBox, 'k', defaultValue: false),
          isTrue,
        );
      });

      test('getInt returns the stored value when present', () async {
        await service.put(HiveKeys.settingsBox, 'k', 123);
        expect(
          service.getInt(HiveKeys.settingsBox, 'k', defaultValue: 0),
          123,
        );
      });

      test('getString returns the stored value when present', () async {
        await service.put(HiveKeys.settingsBox, 'k', 'hello');
        expect(
          service.getString(HiveKeys.settingsBox, 'k', defaultValue: 'fb'),
          'hello',
        );
      });
    });

    group('string-list helpers', () {
      test('getStringList returns const [] when key is absent', () {
        final list =
            service.getStringList(HiveKeys.hiddenAppsBox, 'never_set');
        expect(list, isEmpty);
      });

      test('setStringList + getStringList roundtrip', () async {
        const stored = ['com.a', 'com.b', 'com.c'];
        await service.setStringList(
            HiveKeys.hiddenAppsBox, HiveKeys.hiddenApps, stored);

        final list = service.getStringList(
            HiveKeys.hiddenAppsBox, HiveKeys.hiddenApps);
        expect(list, stored);
      });

      test('setStringList with empty list yields an empty list on read',
          () async {
        await service.setStringList(
            HiveKeys.hiddenAppsBox, HiveKeys.hiddenApps, const []);
        expect(
          service.getStringList(
              HiveKeys.hiddenAppsBox, HiveKeys.hiddenApps),
          isEmpty,
        );
      });

      test('getStringList returns const [] when stored value is not a List',
          () async {
        // Plant a non-list value at the same key — getStringList must
        // gracefully fall back to const [].
        await service.put(HiveKeys.hiddenAppsBox, HiveKeys.hiddenApps,
            'not_a_list_string');
        expect(
          service.getStringList(
              HiveKeys.hiddenAppsBox, HiveKeys.hiddenApps),
          isEmpty,
        );
      });
    });

    group('delete', () {
      test('removes the key, subsequent get returns null', () async {
        await service.put(HiveKeys.settingsBox, 'k', 'v');
        expect(service.get<String>(HiveKeys.settingsBox, 'k'), 'v');

        await service.delete(HiveKeys.settingsBox, 'k');
        expect(service.get<String>(HiveKeys.settingsBox, 'k'), isNull);
      });

      test('delete on a missing key is a no-op', () async {
        // Should not throw.
        await service.delete(HiveKeys.settingsBox, 'never_set');
      });
    });

    group('watch', () {
      test('emits a BoxEvent after a matching put', () async {
        final events = <BoxEvent>[];
        final sub = service.watch(HiveKeys.settingsBox, key: 'k').listen(events.add);

        await service.put(HiveKeys.settingsBox, 'k', 'v1');
        await service.put(HiveKeys.settingsBox, 'k', 'v2');
        // Allow the watcher to deliver.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await sub.cancel();

        expect(events, isNotEmpty);
        expect(events.last.value, 'v2');
        expect(events.last.key, 'k');
        expect(events.last.deleted, isFalse);
      });

      test('without a key argument, emits for any change in the box',
          () async {
        final events = <BoxEvent>[];
        final sub = service.watch(HiveKeys.settingsBox).listen(events.add);

        await service.put(HiveKeys.settingsBox, 'a', 1);
        await service.put(HiveKeys.settingsBox, 'b', 2);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await sub.cancel();

        // We expect at least 2 events (one per put).
        expect(events.length, greaterThanOrEqualTo(2));
        expect(events.map((e) => e.key).toSet(), containsAll({'a', 'b'}));
      });

      test('a delete event reports deleted=true', () async {
        await service.put(HiveKeys.settingsBox, 'k', 'v');
        final events = <BoxEvent>[];
        final sub = service.watch(HiveKeys.settingsBox, key: 'k').listen(events.add);

        await service.delete(HiveKeys.settingsBox, 'k');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await sub.cancel();

        expect(events, isNotEmpty);
        expect(events.last.deleted, isTrue);
      });
    });

    group('_boxFor (unknown box)', () {
      test('get on an unknown box name throws ArgumentError', () {
        expect(
          () => service.get<int>('definitely_not_a_box', 'k'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('put on an unknown box name throws ArgumentError', () {
        expect(
          () => service.put('definitely_not_a_box', 'k', 1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('delete on an unknown box name throws ArgumentError', () {
        expect(
          () => service.delete('definitely_not_a_box', 'k'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('watch on an unknown box name throws ArgumentError', () {
        expect(
          () => service.watch('definitely_not_a_box'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('box isolation', () {
      test('the same key in different boxes does not collide', () async {
        await service.put(HiveKeys.settingsBox, 'k', 'settings_value');
        await service.put(HiveKeys.onboardingBox, 'k', 'onboarding_value');

        expect(
          service.get<String>(HiveKeys.settingsBox, 'k'),
          'settings_value',
        );
        expect(
          service.get<String>(HiveKeys.onboardingBox, 'k'),
          'onboarding_value',
        );
      });
    });
  });
}
