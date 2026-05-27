import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/overlay_config.dart';
import 'package:koru/presentation/screens/block_overlay/overlay_config_style.dart';

void main() {
  group('OverlayConfigStyle.backgroundColor', () {
    test('parses hex to Color with full alpha', () {
      const config = OverlayConfig(backgroundColorHex: '#5C8262');
      final color = config.backgroundColor;
      expect(color.toARGB32().toRadixString(16).toUpperCase(), 'FF5C8262');
    });

    test('default config resolves to the Koru primary green', () {
      final color = OverlayConfig.defaults.backgroundColor;
      expect(color.toARGB32().toRadixString(16).toUpperCase(), 'FF5C8262');
    });

    test('hex without leading # is parsed identically', () {
      const config = OverlayConfig(backgroundColorHex: '123456');
      final color = config.backgroundColor;
      expect(color.toARGB32().toRadixString(16).toUpperCase(), 'FF123456');
    });
  });
}
