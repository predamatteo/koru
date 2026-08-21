import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/unlock_challenge.dart';
import 'package:koru/presentation/widgets/unlock_challenge_glyphs.dart';

/// Il ponte fra gli id simbolici di `domain/` e le icone di `presentation/` è
/// una mappa scritta a mano: aggiungere una variante a [kGlyphFamilies] e
/// scordarsi la entry qui non rompe niente a compile-time — in griglia
/// comparirebbe un punto interrogativo, e solo su un device.
void main() {
  test('ogni glifo di kGlyphFamilies ha un\'icona', () {
    final missing = <String>[];
    for (final family in kGlyphFamilies) {
      for (final variant in family.variants) {
        if (!kGlyphIcons.containsKey(variant)) missing.add(variant);
      }
    }
    expect(missing, isEmpty, reason: 'glifi senza icona: $missing');
  });

  test('nessuna icona orfana in kGlyphIcons', () {
    final known = {
      for (final family in kGlyphFamilies) ...family.variants,
    };
    expect(kGlyphIcons.keys.toSet().difference(known), isEmpty);
  });

  test('dentro una famiglia le icone sono tutte diverse', () {
    for (final family in kGlyphFamilies) {
      final icons = family.variants.map(glyphIcon).toList();
      expect(
        icons.toSet(),
        hasLength(icons.length),
        reason:
            'la famiglia ${family.id} riusa la stessa icona per due varianti: '
            'in griglia sarebbero indistinguibili, non "sosia"',
      );
    }
  });

  test('glyphIcon non lancia su un id sconosciuto', () {
    expect(() => glyphIcon('non_esiste'), returnsNormally);
  });
}
