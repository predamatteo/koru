import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/providers/accessibility_health_provider.dart';
import 'package:koru/presentation/screens/home/widgets/accessibility_health_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('AccessibilityHealthBanner', () {
    testWidgets('shows nothing (SizedBox.shrink) when health is ok',
        (tester) async {
      final h = buildTestContainer(extra: [
        accessibilityHealthProvider.overrideWith(
          (ref) => Stream<bool>.value(true),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: AccessibilityHealthBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quando ok, il banner non mostra niente di significativo.
      expect(find.text('Accessibility is off'), findsNothing);
      expect(find.text('Re-enable'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('shows the warning banner with CTA when health is bad',
        (tester) async {
      final h = buildTestContainer(extra: [
        accessibilityHealthProvider.overrideWith(
          (ref) => Stream<bool>.value(false),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: AccessibilityHealthBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accessibility is off'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Re-enable'), findsOneWidget);
    });

    testWidgets('tapping "Re-enable" opens accessibility settings',
        (tester) async {
      final h = buildTestContainer(extra: [
        accessibilityHealthProvider.overrideWith(
          (ref) => Stream<bool>.value(false),
        ),
      ]);
      addTearDown(h.dispose);

      when(() => h.permission.openAccessibilitySettings())
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: AccessibilityHealthBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-enable'));
      await tester.pump();

      verify(() => h.permission.openAccessibilitySettings()).called(1);
    });

    testWidgets('tapping the banner background also opens settings',
        (tester) async {
      final h = buildTestContainer(extra: [
        accessibilityHealthProvider.overrideWith(
          (ref) => Stream<bool>.value(false),
        ),
      ]);
      addTearDown(h.dispose);

      when(() => h.permission.openAccessibilitySettings())
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: AccessibilityHealthBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // L'intera banner card ha un InkWell che apre i settings.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      verify(() => h.permission.openAccessibilitySettings())
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('while the health check is loading, banner is hidden',
        (tester) async {
      final h = buildTestContainer(extra: [
        accessibilityHealthProvider.overrideWith(
          // Stream che non emette mai → permanently AsyncLoading.
          (ref) => const Stream<bool>.empty(),
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(
            home: Scaffold(body: AccessibilityHealthBanner()),
          ),
        ),
      );
      // Pumps ridotti per non triggerare timer del provider override.
      await tester.pump();

      expect(find.text('Accessibility is off'), findsNothing);
    });
  });
}
