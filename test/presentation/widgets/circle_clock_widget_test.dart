import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/theme/app_theme.dart';
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
      // Senza livello noto niente segmento batteria: nessun `%`, nessuna icona.
      expect(find.byType(Icon), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('%'),
        ),
        findsNothing,
      );
    });

    testWidgets('renders the hour in a scale-down FittedBox', (tester) async {
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(phase: LauncherPhase.night),
        overrides: [
          batteryStateProvider.overrideWith(
            (ref) => const Stream<BatteryState>.empty(),
          ),
        ],
      );

      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('follows the font picked in Settings, never a hardcoded family',
        (tester) async {
      // Regressione: l'orologio ha usato prima Orbitron e poi un serif fissi,
      // ignorando Impostazioni → Font. Con una famiglia insolita nel tema,
      // OGNI riga del widget deve adottarla.
      await pumpKoruWidgetNoSettle(
        tester,
        const CircleClockWidget(phase: LauncherPhase.night),
        theme: AppTheme.dark(fontFamily: 'ArchitectsDaughter'),
        overrides: [
          batteryStateProvider.overrideWith((ref) {
            return Stream<BatteryState>.value(
              const BatteryState(level: 87, charging: false),
            );
          }),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts, isNotEmpty);
      for (final t in texts) {
        expect(
          t.style?.fontFamily,
          'ArchitectsDaughter',
          reason: 'testo: "${t.data}"',
        );
      }
    });

    testWidgets('shows battery percentage when the level is known',
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

      expect(find.text('87%'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsNothing);
    });

    testWidgets('shows the bolt icon when charging', (tester) async {
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

      expect(find.text('42%'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
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
