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

  // Confronta i CODEPOINT, non le `IconData`: due `IconData` diverse per un
  // campo che non si vede (`matchTextDirection`, il package) disegnano lo
  // stesso glifo, e il test sopra le lascerebbe passare.
  test('nessun codepoint usato da due glifi diversi', () {
    final byCodePoint = <int, List<String>>{};
    for (final glyphId in kGlyphIcons.keys) {
      byCodePoint
          .putIfAbsent(glyphIcon(glyphId).codePoint, () => [])
          .add(glyphId);
    }
    final shared = byCodePoint.entries.where((e) => e.value.length > 1);
    expect(
      shared,
      isEmpty,
      reason:
          'stesso glifo per più id: ${shared.map((e) => e.value).toList()}. '
          'Se finiscono nella stessa griglia — uno bersaglio, uno sosia — la '
          'sfida non è difficile, è impossibile.',
    );
  });

  // Non copre il caso generale (icone diverse che *sembrano* uguali si vedono
  // solo guardandole), ma inchioda l'errore già fatto una volta: un quadrato
  // vuoto è indistinguibile dal `.notdef` che il font disegna quando manca un
  // codepoint, e viene letto come icona non caricata invece che come simbolo.
  test('nessun glifo è un quadrato vuoto (si legge come icona mancante)', () {
    const hollowSquares = {
      0xe1ae: 'Icons.crop_square',
      0xe158: 'Icons.check_box_outline_blank',
      0xe1a8: 'Icons.crop_din',
    };
    final offenders = [
      for (final glyphId in kGlyphIcons.keys)
        if (hollowSquares.containsKey(glyphIcon(glyphId).codePoint))
          '$glyphId → ${hollowSquares[glyphIcon(glyphId).codePoint]}',
    ];
    expect(offenders, isEmpty, reason: 'quadrati vuoti in griglia: $offenders');
  });

  test('glyphIcon non lancia su un id sconosciuto', () {
    expect(() => glyphIcon('non_esiste'), returnsNormally);
  });
}
