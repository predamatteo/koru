import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/screens/all_apps/widgets/app_search_bar.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('AppSearchBar', () {
    testWidgets('renders a TextField with the "Search apps" hint',
        (tester) async {
      await pumpKoruWidget(tester, const AppSearchBar());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search apps'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('accepts text input and updates the controller', (tester) async {
      await pumpKoruWidget(tester, const AppSearchBar());

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
              home: Scaffold(body: AppSearchBar()),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'spotify');
      await tester.pump();

      expect(container.read(appSearchQueryProvider), 'spotify');
    });

    testWidgets('clear icon (X) is hidden when text is empty', (tester) async {
      await pumpKoruWidget(tester, const AppSearchBar());

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('clear icon (X) appears once text is entered', (tester) async {
      await pumpKoruWidget(tester, const AppSearchBar());

      await tester.enterText(find.byType(TextField), 'foo');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('tapping clear (X) wipes the field and the provider',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: Scaffold(body: AppSearchBar()),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'instagram');
      await tester.pump();

      expect(container.read(appSearchQueryProvider), 'instagram');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(container.read(appSearchQueryProvider), '');
      expect(find.byIcon(Icons.close), findsNothing);
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
              home: Scaffold(body: AppSearchBar()),
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
