import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/presentation/providers/launcher_shortcuts_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('LauncherShortcuts (value object)', () {
    test('packageFor returns the configured left/right', () {
      const s = LauncherShortcuts(
        leftPackage: 'com.android.dialer',
        rightPackage: 'com.android.camera',
      );
      expect(s.packageFor(LauncherShortcutSlot.left), 'com.android.dialer');
      expect(s.packageFor(LauncherShortcutSlot.right), 'com.android.camera');
    });

    test('copyWith preserves non-null fields', () {
      const s = LauncherShortcuts(
        leftPackage: 'a',
        rightPackage: 'b',
      );
      final s2 = s.copyWith(leftPackage: 'c');
      expect(s2.leftPackage, 'c');
      expect(s2.rightPackage, 'b');
    });

    test('copyWith(clearLeft: true) nukes the left slot', () {
      const s = LauncherShortcuts(leftPackage: 'a', rightPackage: 'b');
      final s2 = s.copyWith(clearLeft: true);
      expect(s2.leftPackage, isNull);
      expect(s2.rightPackage, 'b');
    });

    test('copyWith(clearRight: true) nukes the right slot', () {
      const s = LauncherShortcuts(leftPackage: 'a', rightPackage: 'b');
      final s2 = s.copyWith(clearRight: true);
      expect(s2.leftPackage, 'a');
      expect(s2.rightPackage, isNull);
    });
  });

  group('LauncherShortcutsNotifier', () {
    test('build() reads both shortcut keys from hive uiStateBox', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(
            HiveKeys.uiStateBox,
            HiveKeys.launcherLeftShortcut,
          )).thenReturn('com.android.dialer');
      when(() => h.hive.get<String>(
            HiveKeys.uiStateBox,
            HiveKeys.launcherRightShortcut,
          )).thenReturn('com.android.camera');

      final s = h.container.read(launcherShortcutsProvider);
      expect(s.leftPackage, 'com.android.dialer');
      expect(s.rightPackage, 'com.android.camera');
    });

    test('build() returns nulls when nothing is stored', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(any(), any())).thenReturn(null);

      final s = h.container.read(launcherShortcutsProvider);
      expect(s.leftPackage, isNull);
      expect(s.rightPackage, isNull);
    });

    test('set(left, pkg) persists and updates state for the left slot',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(any(), any())).thenReturn(null);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      final notifier = h.container.read(launcherShortcutsProvider.notifier);
      await notifier.set(LauncherShortcutSlot.left, 'com.x');

      final s = h.container.read(launcherShortcutsProvider);
      expect(s.leftPackage, 'com.x');
      expect(s.rightPackage, isNull);
      verify(() => h.hive.put(
            HiveKeys.uiStateBox,
            HiveKeys.launcherLeftShortcut,
            'com.x',
          )).called(1);
    });

    test('set(right, pkg) only touches the right slot', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(any(), any())).thenReturn(null);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      final notifier = h.container.read(launcherShortcutsProvider.notifier);
      await notifier.set(LauncherShortcutSlot.right, 'com.y');

      expect(
        h.container.read(launcherShortcutsProvider).rightPackage,
        'com.y',
      );
      expect(
        h.container.read(launcherShortcutsProvider).leftPackage,
        isNull,
      );
      verify(() => h.hive.put(
            HiveKeys.uiStateBox,
            HiveKeys.launcherRightShortcut,
            'com.y',
          )).called(1);
    });

    test('clear(left) deletes the key from hive and resets the slot',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(
            HiveKeys.uiStateBox,
            HiveKeys.launcherLeftShortcut,
          )).thenReturn('com.x');
      when(() => h.hive.get<String>(
            HiveKeys.uiStateBox,
            HiveKeys.launcherRightShortcut,
          )).thenReturn(null);
      when(() => h.hive.delete(any(), any())).thenAnswer((_) async {});

      // Initial: left=com.x.
      expect(
        h.container.read(launcherShortcutsProvider).leftPackage,
        'com.x',
      );

      final notifier = h.container.read(launcherShortcutsProvider.notifier);
      await notifier.clear(LauncherShortcutSlot.left);

      expect(
        h.container.read(launcherShortcutsProvider).leftPackage,
        isNull,
      );
      verify(() => h.hive.delete(
            HiveKeys.uiStateBox,
            HiveKeys.launcherLeftShortcut,
          )).called(1);
    });
  });

  group('defaultShortcutPackageProvider', () {
    test('left slot maps to blocking.getDefaultDialerPackage', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getDefaultDialerPackage())
          .thenAnswer((_) async => 'com.android.dialer');

      final pkg = await h.container.read(
        defaultShortcutPackageProvider(LauncherShortcutSlot.left).future,
      );
      expect(pkg, 'com.android.dialer');
    });

    test('right slot maps to blocking.getDefaultCameraPackage', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getDefaultCameraPackage())
          .thenAnswer((_) async => 'com.android.camera');

      final pkg = await h.container.read(
        defaultShortcutPackageProvider(LauncherShortcutSlot.right).future,
      );
      expect(pkg, 'com.android.camera');
    });
  });

  group('effectiveShortcutPackageProvider', () {
    test('returns user override when set, regardless of system default',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(
            HiveKeys.uiStateBox,
            HiveKeys.launcherLeftShortcut,
          )).thenReturn('com.override');
      when(() => h.hive.get<String>(
            HiveKeys.uiStateBox,
            HiveKeys.launcherRightShortcut,
          )).thenReturn(null);
      when(() => h.blocking.getDefaultDialerPackage())
          .thenAnswer((_) async => 'com.android.dialer');

      // Force la build del default.
      await h.container.read(
        defaultShortcutPackageProvider(LauncherShortcutSlot.left).future,
      );

      final pkg = h.container.read(
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left),
      );
      expect(pkg, 'com.override');
    });

    test('falls back to the system default when no override is set',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.hive.get<String>(any(), any())).thenReturn(null);
      when(() => h.blocking.getDefaultCameraPackage())
          .thenAnswer((_) async => 'com.android.camera');

      await h.container.read(
        defaultShortcutPackageProvider(LauncherShortcutSlot.right).future,
      );

      final pkg = h.container.read(
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right),
      );
      expect(pkg, 'com.android.camera');
    });
  });
}
