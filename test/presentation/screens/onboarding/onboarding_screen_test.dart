import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_helpers/provider_test_utils.dart';

void main() {
  group('OnboardingScreen pager', () {
    testWidgets(
        'has 5 pages and 5 dots; final CTA + hidden Skip flip on the last '
        'page (guards the off-by-one)', (tester) async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      // onPageChanged persiste il flag disclosure → stub della put.
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump();

      // Strutturale: l'indicatore ha 5 dot (guarda `total: 5`) e il PageView
      // ha 5 figli (la disclosure è stata inserita). Niente walk-via-tap: non
      // costruiamo le pagine dep-heavy (Permissions/Presets).
      expect(find.byType(AnimatedContainer), findsNWidgets(5));
      final pageView = tester.widget<PageView>(find.byType(PageView));
      final delegate = pageView.childrenDelegate as SliverChildListDelegate;
      expect(delegate.children.length, 5);

      // Prima pagina: Continue + Skip, niente "Enter Koru".
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Enter Koru'), findsNothing);
      expect(find.text('Skip for now'), findsOneWidget);

      // Salta all'ultima pagina (indice 4) via il controller del PageView —
      // evita di costruire la PermissionsPage (indice 2) e usa pump() (non
      // settle) per non incappare in eventuali spinner offscreen.
      pageView.controller!.jumpToPage(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ultima pagina: CTA finale presente, Continue + Skip spariti.
      expect(find.text('Enter Koru'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Skip for now'), findsNothing);
    });
  });
}
