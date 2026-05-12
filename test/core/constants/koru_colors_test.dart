import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/koru_colors.dart';

void main() {
  group('KoruColors literal ARGB values', () {
    test('backgroundBase == 0xFF0E100F', () {
      expect(KoruColors.backgroundBase.toARGB32(), 0xFF0E100F);
    });

    test('primary == 0xFF5C8262', () {
      expect(KoruColors.primary.toARGB32(), 0xFF5C8262);
    });

    test('danger == 0xFFA85449', () {
      expect(KoruColors.danger.toARGB32(), 0xFFA85449);
    });
  });

  group('KoruColors opacity', () {
    final allColors = <String, Color>{
      'backgroundBase': KoruColors.backgroundBase,
      'surface': KoruColors.surface,
      'surfaceElevated': KoruColors.surfaceElevated,
      'primary': KoruColors.primary,
      'primaryContainer': KoruColors.primaryContainer,
      'secondary': KoruColors.secondary,
      'secondaryContainer': KoruColors.secondaryContainer,
      'textPrimary': KoruColors.textPrimary,
      'textSecondary': KoruColors.textSecondary,
      'danger': KoruColors.danger,
      'dangerContainer': KoruColors.dangerContainer,
      'success': KoruColors.success,
      'successContainer': KoruColors.successContainer,
    };

    test('every palette color is fully opaque (alpha == 0xFF)', () {
      for (final entry in allColors.entries) {
        final alpha = (entry.value.toARGB32() >> 24) & 0xFF;
        expect(
          alpha,
          0xFF,
          reason:
              'Color "${entry.key}" is not fully opaque (alpha=0x${alpha.toRadixString(16)})',
        );
      }
    });
  });

  group('KoruColors palette uniqueness', () {
    test('primary and secondary are different colors', () {
      expect(
        KoruColors.primary.toARGB32(),
        isNot(KoruColors.secondary.toARGB32()),
      );
    });

    test('primary and primaryContainer differ (light vs deep variant)', () {
      expect(
        KoruColors.primary.toARGB32(),
        isNot(KoruColors.primaryContainer.toARGB32()),
      );
    });

    test('danger and success differ (semantic separation)', () {
      expect(
        KoruColors.danger.toARGB32(),
        isNot(KoruColors.success.toARGB32()),
      );
    });

    test('textPrimary and textSecondary differ', () {
      expect(
        KoruColors.textPrimary.toARGB32(),
        isNot(KoruColors.textSecondary.toARGB32()),
      );
    });
  });
}
