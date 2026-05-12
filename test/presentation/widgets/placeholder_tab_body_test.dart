import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/home/widgets/placeholder_tab_body.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('PlaceholderTabBody', () {
    testWidgets('renders the provided icon, label and hint', (tester) async {
      await pumpKoruWidget(
        tester,
        const PlaceholderTabBody(
          icon: Icons.timeline,
          label: 'Statistics',
          hint: 'Charts and insights will appear here.',
        ),
      );

      expect(find.text('Statistics'), findsOneWidget);
      expect(
        find.text('Charts and insights will appear here.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('renders different content when props change', (tester) async {
      await pumpKoruWidget(
        tester,
        const PlaceholderTabBody(
          icon: Icons.flag_outlined,
          label: 'Goals',
          hint: 'Define your weekly intentions.',
        ),
      );

      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Define your weekly intentions.'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      // The first test's icon must NOT be present.
      expect(find.byIcon(Icons.timeline), findsNothing);
    });

    testWidgets('is wrapped in a centered Column', (tester) async {
      await pumpKoruWidget(
        tester,
        const PlaceholderTabBody(
          icon: Icons.lightbulb_outline,
          label: 'Tips',
          hint: 'Helpful tips will land here.',
        ),
      );

      expect(find.byType(Center), findsWidgets);
      expect(find.byType(Column), findsOneWidget);
    });
  });
}
