import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/theme/launcher_phase.dart';
import 'package:koru/presentation/providers/battery_provider.dart';
import 'package:koru/presentation/screens/home/widgets/circle_clock_widget.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('CircleClockWidget', () {
    testWidgets('smoke: renders without errors when battery state is unknown',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(phase: LauncherPhase.night),
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
      // Nessuna icona: la riga meta è tutta testo (era `Icons.bolt` +
      // `Icons.battery_*` in colonna sotto l'ora).
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('the meta line carries the phase label but no battery segment '
        'while the level is unknown', (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(phase: LauncherPhase.night),
        overrides: [
          batteryStateProvider.overrideWith(
            (ref) => const Stream<BatteryState>.empty(),
          ),
        ],
      );

      final meta = _metaLine(tester);
      expect(meta, endsWith('NIGHT'));
      expect(meta, isNot(contains('%')));
      // L'ora è resa nella sua FittedBox, separata dalla riga meta.
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('the meta line shows the battery percentage when known',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(phase: LauncherPhase.day),
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

      final meta = _metaLine(tester);
      expect(meta, contains('87%'));
      expect(meta, isNot(contains('CHARGING')));
      expect(meta, endsWith('DAY'));
    });

    testWidgets('charging is spelled out in the meta line, not shown as a bolt',
        (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(phase: LauncherPhase.night),
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

      expect(_metaLine(tester), contains('42% CHARGING'));
      expect(find.byIcon(Icons.bolt), findsNothing);
    });

    testWidgets('tap on the clock invokes onTap callback', (tester) async {
      var taps = 0;
      await pumpKoruWidgetNoSettle(
        tester,
        CircleClockWidget(
          phase: LauncherPhase.night,
          onTap: () => taps++,
        ),
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
        const CircleClockWidget(phase: LauncherPhase.night),
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

/// La riga meta è l'unico `Text` che contiene il separatore ` · `.
String _metaLine(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').contains(' · '),
  );
  expect(finder, findsOneWidget);
  return tester.widget<Text>(finder).data!;
}
