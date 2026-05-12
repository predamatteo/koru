import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/countdown_state.dart';

void main() {
  group('CountdownPhase', () {
    test('has exactly 4 values', () {
      expect(CountdownPhase.values.length, 4);
    });

    test('declares the expected values in order', () {
      expect(CountdownPhase.values, <CountdownPhase>[
        CountdownPhase.initialized,
        CountdownPhase.animating,
        CountdownPhase.paused,
        CountdownPhase.finished,
      ]);
    });

    test('initialized.name == "initialized"', () {
      expect(CountdownPhase.initialized.name, 'initialized');
    });

    test('animating.name == "animating"', () {
      expect(CountdownPhase.animating.name, 'animating');
    });

    test('paused.name == "paused"', () {
      expect(CountdownPhase.paused.name, 'paused');
    });

    test('finished.name == "finished"', () {
      expect(CountdownPhase.finished.name, 'finished');
    });

    test('all names are unique', () {
      final names = CountdownPhase.values.map((p) => p.name).toSet();
      expect(names.length, CountdownPhase.values.length);
    });
  });
}
