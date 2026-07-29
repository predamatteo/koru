import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/widgets/koru_spiral.dart';

import '../../_helpers/widget_test_utils.dart';

void main() {
  group('KoruSpiral', () {
    testWidgets('occupies exactly the requested square', (tester) async {
      await pumpKoruWidget(
        tester,
        const Center(
          child: KoruSpiral(size: 22, color: Color(0xFFC0F3BB)),
        ),
      );

      expect(tester.getSize(find.byType(KoruSpiral)), const Size(22, 22));
    });

    testWidgets('paints at any size without throwing', (tester) async {
      // Il glifo è scalato sul proprio bounding box: le misure estreme
      // esercitano il fattore di scala, non un percorso hardcoded.
      for (final size in [1.0, 22.0, 200.0]) {
        await pumpKoruWidget(
          tester,
          Center(child: KoruSpiral(size: size, color: const Color(0xFFE6C08C))),
        );
        expect(tester.takeException(), isNull, reason: 'size $size');
      }
    });

    testWidgets('a degenerate size is a no-op, not a crash', (tester) async {
      // Guardia su `side <= 0`: senza, il fattore di scala sarebbe 0 e il
      // canvas riceverebbe una trasformazione non invertibile.
      await pumpKoruWidget(
        tester,
        const Center(child: KoruSpiral(size: 0, color: Color(0xFFA4D6A0))),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KoruSpiral)), Size.zero);
    });

    testWidgets('changing colour repaints without rebuilding the tree',
        (tester) async {
      await pumpKoruWidget(
        tester,
        const Center(child: KoruSpiral(size: 40, color: Color(0xFFA4D6A0))),
      );
      await pumpKoruWidget(
        tester,
        const Center(child: KoruSpiral(size: 40, color: Color(0xFFE6C08C))),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(KoruSpiral), findsOneWidget);
    });
  });
}
