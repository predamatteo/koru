import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/providers/battery_provider.dart';
import 'package:koru/presentation/screens/home/widgets/circle_clock_widget.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('CircleClockWidget', () {
    testWidgets('smoke: renders without errors when battery state is unknown',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(),
        overrides: [
          // -1 = level unparseable → il provider derivato espone AsyncData(-1),
          // ma il `Provider<AsyncValue<int>>` resta whenData mapping → valueOrNull = -1.
          // Per ottenere null, override il top-level con AsyncLoading.
          batteryStateProvider.overrideWith(
            (ref) => const Stream<BatteryState>.empty(),
          ),
        ],
      );

      expect(find.byType(CircleClockWidget), findsOneWidget);
      // No battery row when batteryLevel == null.
      // Le textTheme dipendono dal theme; controlliamo la presenza dell'icona
      // batteria solo come negativa.
      expect(find.byIcon(Icons.battery_full), findsNothing);
      expect(find.byIcon(Icons.bolt), findsNothing);
    });

    testWidgets('renders a Column with main columns and FittedBox',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(),
        overrides: [
          batteryStateProvider.overrideWith(
            (ref) => const Stream<BatteryState>.empty(),
          ),
        ],
      );

      expect(find.byType(Column), findsWidgets);
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('shows battery percentage when batteryLevel is provided',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(),
        overrides: [
          batteryStateProvider.overrideWith((ref) {
            return Stream<BatteryState>.value(
              const BatteryState(level: 87, charging: false),
            );
          }),
        ],
      );
      // Pump several times to let the stream emit + UI rebuild.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('87%'), findsOneWidget);
      // 87 >= 70 → battery_6_bar icon.
      expect(find.byIcon(Icons.battery_6_bar), findsOneWidget);
    });

    testWidgets('shows bolt icon when charging', (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(),
        overrides: [
          batteryStateProvider.overrideWith((ref) {
            return Stream<BatteryState>.value(
              const BatteryState(level: 42, charging: true),
            );
          }),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('42%'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('tap on the clock invokes onTap callback', (tester) async {
      var taps = 0;
      await pumpKoruWidgetNoSettle(
        tester,
        CircleClockWidget(onTap: () => taps++),
        overrides: [
          batteryStateProvider.overrideWith(
            (ref) => const Stream<BatteryState>.empty(),
          ),
        ],
      );

      await tester.tap(find.byType(CircleClockWidget));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('renders a digit (current minute) somewhere in the tree',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(),
        overrides: [
          batteryStateProvider.overrideWith(
            (ref) => const Stream<BatteryState>.empty(),
          ),
        ],
      );

      // L'ora è formattata Hm (HH:mm) — almeno un Text che contenga `:`.
      final colonFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(':'),
      );
      expect(colonFinder, findsAtLeastNWidgets(1));
    });
  });
}
