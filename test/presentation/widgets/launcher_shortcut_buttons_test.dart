import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koru/presentation/providers/launcher_shortcuts_provider.dart';
import 'package:koru/presentation/screens/launcher/widgets/launcher_shortcut_buttons.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

Widget _wrap(ProviderContainer container, Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
      GoRoute(
        path: '/launcher/shortcut',
        builder: (_, _) => const Scaffold(body: Text('Picker')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('LauncherShortcutButtons', () {
    testWidgets('smoke: renders two shortcut buttons (phone + camera)',
        (tester) async {
      final h = buildTestContainer(extra: [
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left)
            .overrideWith((ref) => 'com.android.dialer'),
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right)
            .overrideWith((ref) => 'com.android.camera'),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const LauncherShortcutButtons()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('left button tap launches the left shortcut package',
        (tester) async {
      final h = buildTestContainer(extra: [
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left)
            .overrideWith((ref) => 'com.dialer.left'),
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right)
            .overrideWith((ref) => 'com.camera.right'),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(_wrap(h.container, const LauncherShortcutButtons()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();

      verify(() => h.blocking.launchApp('com.dialer.left')).called(1);
      verifyNever(() => h.blocking.launchApp('com.camera.right'));
    });

    testWidgets('right button tap launches the right shortcut package',
        (tester) async {
      final h = buildTestContainer(extra: [
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left)
            .overrideWith((ref) => 'com.dialer.left'),
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right)
            .overrideWith((ref) => 'com.camera.right'),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(_wrap(h.container, const LauncherShortcutButtons()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pump();

      verify(() => h.blocking.launchApp('com.camera.right')).called(1);
    });

    testWidgets('tap is a no-op when the package is null', (tester) async {
      final h = buildTestContainer(extra: [
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left)
            .overrideWith((ref) => null),
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right)
            .overrideWith((ref) => null),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(_wrap(h.container, const LauncherShortcutButtons()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();

      verifyNever(() => h.blocking.launchApp(any()));
    });

    testWidgets('tap is a no-op when the package is empty string',
        (tester) async {
      final h = buildTestContainer(extra: [
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left)
            .overrideWith((ref) => ''),
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right)
            .overrideWith((ref) => ''),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(_wrap(h.container, const LauncherShortcutButtons()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pump();

      verifyNever(() => h.blocking.launchApp(any()));
    });

    testWidgets('long-press on the left button navigates to the picker',
        (tester) async {
      final h = buildTestContainer(extra: [
        effectiveShortcutPackageProvider(LauncherShortcutSlot.left)
            .overrideWith((ref) => 'com.x'),
        effectiveShortcutPackageProvider(LauncherShortcutSlot.right)
            .overrideWith((ref) => 'com.y'),
      ]);
      addTearDown(h.dispose);

      when(() => h.blocking.launchApp(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(_wrap(h.container, const LauncherShortcutButtons()));
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      // Il fake destination della rotta mostra "Picker".
      expect(find.text('Picker'), findsOneWidget);
    });
  });
}
