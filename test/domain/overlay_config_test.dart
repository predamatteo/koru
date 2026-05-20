import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/overlay_config.dart';

void main() {
  group('OverlayConfig', () {
    test('defaults', () {
      const config = OverlayConfig.defaults;
      expect(config.backgroundColorHex, '#5C8262');
      expect(config.countdownSeconds, 8);
      expect(config.allowBypassAfterCountdown, isTrue);
    });

    test('JSON roundtrip preserves all fields', () {
      const config = OverlayConfig(
        backgroundColorHex: '#5C8262',
        messageTitle: 'Pause',
        messageSubtitle: 'Breathe',
        countdownSeconds: 12,
        shakeEnabled: true,
        allowBypassAfterCountdown: false,
      );
      final restored = OverlayConfig.fromJsonString(config.toJsonString());
      expect(restored.backgroundColorHex, '#5C8262');
      expect(restored.messageTitle, 'Pause');
      expect(restored.messageSubtitle, 'Breathe');
      expect(restored.countdownSeconds, 12);
      expect(restored.shakeEnabled, isTrue);
      expect(restored.allowBypassAfterCountdown, isFalse);
    });

    test('fromJsonString falls back to defaults on malformed input', () {
      final restored = OverlayConfig.fromJsonString('{not json');
      expect(
        restored.backgroundColorHex,
        OverlayConfig.defaults.backgroundColorHex,
      );
    });

    test('backgroundColor parses hex to Color with full alpha', () {
      const config = OverlayConfig(backgroundColorHex: '#5C8262');
      final color = config.backgroundColor;
      expect(color.toARGB32().toRadixString(16).toUpperCase(), 'FF5C8262');
    });
  });
}
