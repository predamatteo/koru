import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/theme/launcher_phase.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/screens/all_apps/widgets/app_search_bar.dart';

import '../../_helpers/widget_test_utils.dart';

const _bar = AppSearchBar(phase: LauncherPhase.night, matchCount: 34);

void main() {
  group('AppSearchBar', () {
    testWidgets('is a bare writing line: slash, field, count — no Material box',
        (tester) async {
      await pumpKoruWidget(tester, _bar);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('TYPE TO FILTER'), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      // Il campo ricerca non è più un box grigio con la lente: zero icone.
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('accepts text input and updates the controller', (tester) async {
      await pumpKoruWidget(tester, _bar);

      await tester.enterText(find.byType(TextField), 'whatsapp');
      await tester.pump();

      expect(find.text('whatsapp'), findsOneWidget);
    });

    testWidgets('updates appSearchQueryProvider on text change', (tester) async {
      // Catturiamo lo stato del provider dopo l'input.
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: Scaffold(body: _bar),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'spotify');
      // Il provider è aggiornato con debounce (~180ms): avanza oltre la finestra.
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(appSearchQueryProvider), 'spotify');
    });

    testWidgets('CLR is hidden when the field is empty', (tester) async {
      await pumpKoruWidget(tester, _bar);

      expect(find.text('CLR'), findsNothing);
    });

    testWidgets('CLR appears once text is entered', (tester) async {
      await pumpKoruWidget(tester, _bar);

      await tester.enterText(find.byType(TextField), 'foo');
      await tester.pump();

      expect(find.text('CLR'), findsOneWidget);
    });

    testWidgets('tapping CLR wipes the field and the provider', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: Scaffold(body: _bar),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'instagram');
      // Attendi il debounce prima di leggere il provider.
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(appSearchQueryProvider), 'instagram');

      await tester.tap(find.text('CLR'));
      await tester.pump();

      expect(container.read(appSearchQueryProvider), '');
      expect(find.text('CLR'), findsNothing);
    });

    testWidgets(
        'external provider reset propagates to the TextField (listener path)',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: Scaffold(body: _bar),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      // Pre-popola il campo via provider esterno.
      container.read(appSearchQueryProvider.notifier).state = 'maps';
      await tester.pump();
      expect(find.text('maps'), findsOneWidget);

      // Reset esterno → ramo `ref.listen` deve svuotare il TextField.
      container.read(appSearchQueryProvider.notifier).state = '';
      await tester.pump();
      expect(find.text('maps'), findsNothing);
    });
  });
}
