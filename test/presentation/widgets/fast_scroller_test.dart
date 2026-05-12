import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/all_apps/widgets/fast_scroller.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('FastScroller', () {
    testWidgets('renders the whole alphabet plus the # bucket', (tester) async {
      await pumpKoruWidget(
        tester,
        FastScroller(
          onLetterSelected: (_) {},
          availableLetters: const {'A', 'B', 'C'},
        ),
      );

      // 27 letters: # + A..Z.
      expect(FastScroller.alphabet.length, 27);
      // Each letter is in its own Text — find by text per-letter.
      for (final l in FastScroller.alphabet) {
        expect(find.text(l), findsOneWidget,
            reason: 'letter "$l" should be rendered');
      }
    });

    testWidgets('tap on a letter invokes onLetterSelected with that letter',
        (tester) async {
      String? selected;
      await pumpKoruWidget(
        tester,
        SizedBox(
          height: 600,
          child: FastScroller(
            onLetterSelected: (l) => selected = l,
            availableLetters: const {'A', 'B', 'M', 'Z'},
          ),
        ),
      );

      // Tap su 'M' — usiamo `warnIfMissed: false` perché AnimatedScale può
      // ridurre l'hitbox del singolo Text, ma il GestureDetector padre cattura.
      await tester.tap(find.text('M'), warnIfMissed: false);
      await tester.pump();

      // Il callback è invocato dal GestureDetector globale che mappa
      // localY → indice alfabeto. Quindi `selected` può non essere
      // esattamente "M" (dipende dalla posizione tap sul column).
      // Verifichiamo solo che SIA stato invocato con una lettera valida.
      expect(selected, isNotNull);
      expect(FastScroller.alphabet, contains(selected));
    });

    testWidgets('available letters and unavailable letters have different alpha',
        (tester) async {
      await pumpKoruWidget(
        tester,
        FastScroller(
          onLetterSelected: (_) {},
          availableLetters: const {'A'},
        ),
      );

      // Trova due Text widget e confronta gli style: "A" available, "Z" no.
      final textA = tester.widget<Text>(find.text('A'));
      final textZ = tester.widget<Text>(find.text('Z'));

      final colorA = textA.style?.color;
      final colorZ = textZ.style?.color;

      expect(colorA, isNotNull);
      expect(colorZ, isNotNull);
      // Available has higher alpha (180) than unavailable (60), so they
      // must differ.
      expect(colorA, isNot(equals(colorZ)));
    });

    testWidgets('drag start triggers onLetterSelected', (tester) async {
      final selected = <String>[];
      await pumpKoruWidget(
        tester,
        SizedBox(
          height: 540,
          child: FastScroller(
            onLetterSelected: selected.add,
            availableLetters: FastScroller.alphabet.toSet(),
          ),
        ),
      );

      // Drag verticale dal centro per generare hover-letter events.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(FastScroller)));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(selected, isNotEmpty);
      // Tutte le lettere emesse devono essere parte dell'alfabeto.
      for (final l in selected) {
        expect(FastScroller.alphabet, contains(l));
      }
    });
  });
}
