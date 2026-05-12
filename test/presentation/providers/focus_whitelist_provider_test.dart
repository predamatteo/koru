import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/default_whitelist.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/presentation/providers/focus_whitelist_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group('focusWhitelistProvider (quickBlock)', () {
    test('build() returns default whitelist when hive is empty', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);

      final wl =
          h.container.read(focusWhitelistProvider(FocusMode.quickBlock));
      expect(wl, kDefaultFocusWhitelist);
    });

    test('build() merges stored user packages with kDefaultFocusWhitelist',
        () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(['com.user.custom']);

      final wl =
          h.container.read(focusWhitelistProvider(FocusMode.quickBlock));
      expect(wl, contains('com.user.custom'));
      // I default sono comunque presenti.
      for (final pkg in kDefaultFocusWhitelist) {
        expect(wl, contains(pkg));
      }
    });

    test('add() inserts a package, persists, and updates state', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier = h.container
          .read(focusWhitelistProvider(FocusMode.quickBlock).notifier);
      await notifier.add('com.x');

      expect(
        h.container.read(focusWhitelistProvider(FocusMode.quickBlock)),
        contains('com.x'),
      );
      verify(() => h.hive.setStringList(
            HiveKeys.uiStateBox,
            'quick_block_whitelist',
            any(),
          )).called(1);
    });

    test('remove() drops a package and persists', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(['com.x']);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier = h.container
          .read(focusWhitelistProvider(FocusMode.quickBlock).notifier);
      await notifier.remove('com.x');

      expect(
        h.container.read(focusWhitelistProvider(FocusMode.quickBlock)),
        isNot(contains('com.x')),
      );
    });

    test('toggle() flips membership', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier = h.container
          .read(focusWhitelistProvider(FocusMode.quickBlock).notifier);
      await notifier.toggle('com.x');
      expect(
        h.container.read(focusWhitelistProvider(FocusMode.quickBlock)),
        contains('com.x'),
      );
      await notifier.toggle('com.x');
      expect(
        h.container.read(focusWhitelistProvider(FocusMode.quickBlock)),
        isNot(contains('com.x')),
      );
    });

    test('resetToDefaults() restores kDefaultFocusWhitelist', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(['com.x']);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier = h.container
          .read(focusWhitelistProvider(FocusMode.quickBlock).notifier);
      await notifier.resetToDefaults();

      expect(
        h.container.read(focusWhitelistProvider(FocusMode.quickBlock)),
        kDefaultFocusWhitelist,
      );
    });
  });

  group('focusWhitelistProvider (pomodoro)', () {
    test('uses a different hive key than quickBlock', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.getStringList(any(), any()))
          .thenReturn(const <String>[]);
      when(() => h.hive.setStringList(any(), any(), any()))
          .thenAnswer((_) async {});

      final notifier = h.container
          .read(focusWhitelistProvider(FocusMode.pomodoro).notifier);
      await notifier.add('com.pom');

      verify(() => h.hive.setStringList(
            HiveKeys.uiStateBox,
            'pomodoro_whitelist',
            any(),
          )).called(1);
      verifyNever(() => h.hive.setStringList(
            HiveKeys.uiStateBox,
            'quick_block_whitelist',
            any(),
          ));
    });
  });
}
