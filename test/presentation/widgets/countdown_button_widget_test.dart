import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/block_overlay/widgets/countdown_button_widget.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('CountdownButtonWidget', () {
    testWidgets('smoke: renders without errors with durationMs=5000',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CountdownButtonWidget(durationMs: 5000),
      );

      expect(find.byType(CountdownButtonWidget), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('shows the initial countdown number on first frame',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CountdownButtonWidget(durationMs: 5000),
      );
      // Dopo il postFrame callback, lo stato passa ad animating
      // e _remainingSeconds parte da ceil(5) = 5.
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('transitions to "finished" after durationMs elapses',
        (tester) async {
      var finishedCalls = 0;
      await pumpKoruWidgetNoSettle(
        tester,
        CountdownButtonWidget(
          durationMs: 1000,
          finishedText: 'Open',
          onFinished: () => finishedCalls++,
        ),
      );
      await tester.pump(); // run postFrame → start animation

      // Avanza il tempo oltre la durata; piccolo padding per chiudere
      // il ticker.
      await tester.pump(const Duration(milliseconds: 1100));
      // AnimatedSwitcher fade per il cambio testo.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Open'), findsOneWidget);
      expect(finishedCalls, 1);
    });

    testWidgets('tap while finished invokes onTap', (tester) async {
      var tapped = 0;
      await pumpKoruWidgetNoSettle(
        tester,
        CountdownButtonWidget(
          durationMs: 500,
          finishedText: 'Open',
          onTap: () => tapped++,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 200));

      // Sanity: deve essere in fase finished.
      expect(find.text('Open'), findsOneWidget);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('tap while animating switches text to "Paused"',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CountdownButtonWidget(durationMs: 10000),
      );
      // Lascia partire l'animazione.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Dovremmo essere in ANIMATING — verifichiamo NON sia finished.
      expect(find.text('Open'), findsNothing);

      // Tap durante animating → PAUSED.
      await tester.tap(find.byType(GestureDetector));
      // AnimatedSwitcher fade per il cambio testo.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('tap while paused resumes the animation', (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CountdownButtonWidget(durationMs: 10000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Pausa.
      await tester.tap(find.byType(GestureDetector));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Paused'), findsOneWidget);

      // Resume.
      await tester.tap(find.byType(GestureDetector));
      await tester.pump(const Duration(milliseconds: 200));
      // Dopo resume, il testo NON è più "Paused".
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('Semantics label reflects countdown state', (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CountdownButtonWidget(durationMs: 3000),
      );
      await tester.pump();
      // L'attributo Semantics.button = true.
      final semantics = tester.getSemantics(find.byType(CountdownButtonWidget));
      expect(semantics.label, contains('Countdown'));
    });
  });
}
