import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/block_overlay/widgets/mindful_intention_prompt.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('MindfulIntentionPrompt', () {
    testWidgets('smoke: renders the title and suggested chips', (tester) async {
      await pumpKoruWidget(
        tester,
        const MindfulIntentionPrompt(
          suggestions: ['Quick check', 'Reply to a message', 'Boredom'],
        ),
      );

      expect(find.text('Why are you opening it?'), findsOneWidget);
      expect(find.text('Quick check'), findsOneWidget);
      expect(find.text('Reply to a message'), findsOneWidget);
      expect(find.text('Boredom'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets('renders an empty wrap when suggestions list is empty',
        (tester) async {
      await pumpKoruWidget(
        tester,
        const MindfulIntentionPrompt(suggestions: []),
      );

      expect(find.text('Why are you opening it?'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('tap on a suggestion invokes onIntentionChosen with that text',
        (tester) async {
      String? chosen;
      await pumpKoruWidget(
        tester,
        MindfulIntentionPrompt(
          suggestions: const ['Work', 'Connect'],
          onIntentionChosen: (s) => chosen = s,
        ),
      );

      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(chosen, 'Connect');
    });

    testWidgets('tapping a chip marks it selected (visual state)',
        (tester) async {
      await pumpKoruWidget(
        tester,
        const MindfulIntentionPrompt(suggestions: ['A', 'B']),
      );

      // Pre-tap: neither chip is selected.
      var chipA = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'A'));
      var chipB = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'B'));
      expect(chipA.selected, isFalse);
      expect(chipB.selected, isFalse);

      // Tap su A.
      await tester.tap(find.text('A'));
      await tester.pump();

      chipA = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'A'));
      chipB = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'B'));
      expect(chipA.selected, isTrue);
      expect(chipB.selected, isFalse);
    });

    testWidgets('selecting a second chip moves the selection', (tester) async {
      await pumpKoruWidget(
        tester,
        const MindfulIntentionPrompt(suggestions: ['A', 'B']),
      );

      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();

      final chipA =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'A'));
      final chipB =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'B'));
      expect(chipA.selected, isFalse);
      expect(chipB.selected, isTrue);
    });
  });
}
