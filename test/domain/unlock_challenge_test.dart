import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/unlock_challenge.dart';

/// Le proprietà testate qui non sono cosmetiche: sono ciò che distingue la
/// sfida da una griglia di icone a caso.
///  - i bersagli vengono da famiglie diverse (li distingui fra loro);
///  - ogni bersaglio ha almeno un sosia della sua famiglia in griglia (non
///    scremi la griglia a colpo d'occhio);
///  - nessun id duplicato (un tocco non è mai ambiguo).
/// Ognuna può rompersi in silenzio riordinando [kGlyphFamilies]: qui si vede.
void main() {
  /// Famiglia di appartenenza di un glifo, o null se orfano.
  String? familyOf(String glyphId) {
    for (final family in kGlyphFamilies) {
      if (family.variants.contains(glyphId)) return family.id;
    }
    return null;
  }

  final activeLevels = UnlockChallengeLevel.values.where((l) => l.isActive);

  group('kGlyphFamilies', () {
    test('nessun id di glifo appartiene a due famiglie', () {
      final seen = <String>{};
      for (final family in kGlyphFamilies) {
        for (final variant in family.variants) {
          expect(
            seen.add(variant),
            isTrue,
            reason: '$variant compare in più di una famiglia',
          );
        }
      }
    });

    test('ogni famiglia ha almeno 3 varianti (servono i sosia)', () {
      for (final family in kGlyphFamilies) {
        expect(
          family.variants.length,
          greaterThanOrEqualTo(3),
          reason: 'la famiglia ${family.id} ha troppe poche varianti',
        );
      }
    });
  });

  group('UnlockChallengeLevel', () {
    test('gridSize è divisibile per columns', () {
      for (final level in activeLevels) {
        expect(level.gridSize % level.columns, 0, reason: level.name);
      }
    });

    test('la griglia lascia spazio ad almeno un sosia per bersaglio', () {
      for (final level in activeLevels) {
        expect(
          level.gridSize - level.sequenceLength,
          greaterThanOrEqualTo(level.sequenceLength),
          reason: level.name,
        );
      }
    });

    test('fromStorage fa round-trip di storageValue', () {
      for (final level in UnlockChallengeLevel.values) {
        expect(UnlockChallengeLevel.fromStorage(level.storageValue), level);
      }
    });

    test('fromStorage degrada al fallback su valori ignoti o assenti', () {
      // Mai configurato ⇒ l'attrito c'è: chi installa Koru lo installa per
      // avere dei limiti, non per doverli accendere a mano.
      expect(
        UnlockChallengeLevel.fromStorage(null),
        UnlockChallengeLevel.fallback,
      );
      expect(
        UnlockChallengeLevel.fromStorage(''),
        UnlockChallengeLevel.fallback,
      );
      expect(
        UnlockChallengeLevel.fromStorage('impossibile'),
        UnlockChallengeLevel.fallback,
      );
      // Un vecchio salvataggio numerico non deve diventare un livello a caso.
      expect(
        UnlockChallengeLevel.fromStorage('2'),
        UnlockChallengeLevel.fallback,
      );
    });

    test('il fallback è un livello attivo, non off', () {
      expect(UnlockChallengeLevel.fallback.isActive, isTrue);
    });

    test('"off" scelto esplicitamente viene rispettato', () {
      // Il degrado va SOLO verso la direzione protettiva: chi ha spento
      // l'attrito di proposito non deve ritrovarselo acceso al riavvio.
      expect(
        UnlockChallengeLevel.fromStorage(UnlockChallengeLevel.off.storageValue),
        UnlockChallengeLevel.off,
      );
    });
  });

  group('generateUnlockChallenge', () {
    test('rifiuta il livello off', () {
      expect(
        () => generateUnlockChallenge(UnlockChallengeLevel.off),
        throwsStateError,
      );
    });

    // 60 semi diversi per livello: la generazione è randomizzata e alcune
    // proprietà (i sosia round-robin, il riempimento) dipendono da quali
    // famiglie escono per prime.
    for (final level in activeLevels) {
      group(level.name, () {
        test('rispetta lunghezza sequenza e dimensione griglia', () {
          for (var seed = 0; seed < 60; seed++) {
            final c = generateUnlockChallenge(level, random: Random(seed));
            expect(c.sequence, hasLength(level.sequenceLength));
            expect(c.grid, hasLength(level.gridSize));
            expect(c.columns, level.columns);
            expect(c.memorizeDuration, level.memorizeDuration);
          }
        });

        test('la griglia non contiene id duplicati', () {
          for (var seed = 0; seed < 60; seed++) {
            final c = generateUnlockChallenge(level, random: Random(seed));
            expect(c.grid.toSet(), hasLength(c.grid.length), reason: '$seed');
          }
        });

        test('la griglia contiene tutti i bersagli', () {
          for (var seed = 0; seed < 60; seed++) {
            final c = generateUnlockChallenge(level, random: Random(seed));
            expect(c.grid, containsAll(c.sequence), reason: '$seed');
          }
        });

        test('i bersagli vengono da famiglie diverse', () {
          for (var seed = 0; seed < 60; seed++) {
            final c = generateUnlockChallenge(level, random: Random(seed));
            final families = c.sequence.map(familyOf).toList();
            expect(families, everyElement(isNotNull), reason: '$seed');
            expect(families.toSet(), hasLength(families.length), reason: '$seed');
          }
        });

        test('ogni bersaglio ha almeno un sosia in griglia', () {
          for (var seed = 0; seed < 60; seed++) {
            final c = generateUnlockChallenge(level, random: Random(seed));
            for (final target in c.sequence) {
              final family = familyOf(target);
              final siblings = c.grid.where(
                (g) => g != target && familyOf(g) == family,
              );
              expect(
                siblings,
                isNotEmpty,
                reason: 'seed $seed: "$target" è senza sosia in griglia',
              );
            }
          }
        });
      });
    }

    test('isCorrectNext accetta solo il glifo in posizione progress', () {
      final c = generateUnlockChallenge(
        UnlockChallengeLevel.standard,
        random: Random(7),
      );
      for (var i = 0; i < c.length; i++) {
        expect(c.isCorrectNext(i, c.sequence[i]), isTrue);
      }
      // Il glifo giusto ma nel posto sbagliato non passa: l'ORDINE conta.
      expect(c.isCorrectNext(1, c.sequence[0]), isFalse);
      // Un glifo che non è nella sequenza non passa mai.
      final intruder = c.grid.firstWhere((g) => !c.sequence.contains(g));
      expect(c.isCorrectNext(0, intruder), isFalse);
      // Indici fuori range: niente crash, niente "sforamento".
      expect(c.isCorrectNext(-1, c.sequence[0]), isFalse);
      expect(c.isCorrectNext(c.length, c.sequence[0]), isFalse);
    });

    test('sequenceSlots ritrova le caselle dei bersagli', () {
      for (var seed = 0; seed < 40; seed++) {
        final c = generateUnlockChallenge(
          UnlockChallengeLevel.standard,
          random: Random(seed),
        );
        final slots = c.sequenceSlots;
        // Nessun -1: ogni bersaglio è in griglia (indexOf lo trova).
        expect(slots, everyElement(greaterThanOrEqualTo(0)), reason: '$seed');
        for (var i = 0; i < slots.length; i++) {
          expect(c.grid[slots[i]], c.sequence[i], reason: 'seed $seed, pos $i');
        }
      }
    });

    test('due sfide di fila non sono la stessa (niente memoria muscolare)', () {
      // Con Random.secure() reale: 40 generazioni devono dare almeno una
      // manciata di sequenze distinte. Un generatore degenere (sempre la
      // stessa) fallirebbe qui.
      final sequences = <String>{};
      for (var i = 0; i < 40; i++) {
        sequences.add(
          generateUnlockChallenge(UnlockChallengeLevel.standard).sequence.join(),
        );
      }
      expect(sequences.length, greaterThan(10));
    });
  });

  /// Variante usata dallo strict mode: le caselle della sequenza le sceglie
  /// Kotlin, i simboli li sceglie il Dart. Se questa piazzatura sbagliasse,
  /// l'utente toccherebbe i simboli giusti e il nativo riceverebbe caselle
  /// sbagliate — puzzle irrisolvibile, e nessuno capirebbe perché.
  group('buildUnlockChallengeForSlots', () {
    const gridSize = 12;
    const slots = [7, 2, 10, 0];

    UnlockChallenge build({int seed = 0, List<int> sequenceSlots = slots}) =>
        buildUnlockChallengeForSlots(
          gridSize: gridSize,
          columns: 3,
          memorizeDuration: const Duration(seconds: 4),
          sequenceSlots: sequenceSlots,
          random: Random(seed),
        );

    test('mette i bersagli esattamente nelle caselle richieste', () {
      for (var seed = 0; seed < 60; seed++) {
        final c = build(seed: seed);
        expect(c.sequenceSlots, slots, reason: '$seed');
        for (var i = 0; i < slots.length; i++) {
          expect(c.grid[slots[i]], c.sequence[i], reason: 'seed $seed, pos $i');
        }
      }
    });

    test('riempie tutta la griglia senza duplicati', () {
      for (var seed = 0; seed < 60; seed++) {
        final c = build(seed: seed);
        expect(c.grid, hasLength(gridSize), reason: '$seed');
        expect(c.grid.toSet(), hasLength(gridSize), reason: '$seed');
      }
    });

    test('conserva le proprietà che rendono il puzzle difficile', () {
      for (var seed = 0; seed < 60; seed++) {
        final c = build(seed: seed);
        final families = c.sequence.map(familyOf).toList();
        expect(families.toSet(), hasLength(families.length), reason: '$seed');
        for (final target in c.sequence) {
          final siblings = c.grid.where(
            (g) => g != target && familyOf(g) == familyOf(target),
          );
          expect(siblings, isNotEmpty, reason: 'seed $seed: "$target" senza sosia');
        }
      }
    });

    test('rifiuta spec malformate invece di produrre un puzzle rotto', () {
      // Casella fuori griglia.
      expect(
        () => build(sequenceSlots: const [0, 1, gridSize]),
        throwsArgumentError,
      );
      expect(() => build(sequenceSlots: const [-1, 1]), throwsArgumentError);
      // Casella ripetuta: due bersagli nella stessa posizione.
      expect(() => build(sequenceSlots: const [3, 3]), throwsArgumentError);
      // Nessun bersaglio, o più bersagli che caselle.
      expect(() => build(sequenceSlots: const []), throwsArgumentError);
      expect(
        () => build(sequenceSlots: List.generate(gridSize + 1, (i) => i)),
        throwsArgumentError,
      );
    });
  });
}
