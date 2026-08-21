/// Sfida di sblocco: l'attrito cognitivo richiesto per **disattivare** una
/// protezione (spegnere un profilo, cancellarlo, togliergli app bloccate).
///
/// Non è sicurezza — è un dosso. Il razionale è lo stesso della pausa di
/// respiro prima di aprire un'app bloccata: l'impulso a "spegnere tutto" dura
/// pochi secondi, e obbligare a memorizzare e ricostruire una sequenza costringe
/// a uscire dal pilota automatico. Chi decide davvero passa in 15 secondi; chi
/// sta solo cedendo di solito molla.
///
/// Meccanica (due fasi):
///  1. **Memorizza** — vengono mostrati [UnlockChallenge.sequence] glifi in
///     ordine, per [UnlockChallengeLevel.memorizeDuration]. Poi spariscono.
///  2. **Ricostruisci** — appare [UnlockChallenge.grid]: gli stessi glifi
///     MESCOLATI, annegati fra **distrattori della stessa famiglia visiva**
///     (la freccia su accanto alla freccia giù, la stella piena accanto a
///     quella vuota). Vanno toccati nell'ordine originale.
///
/// I distrattori sono il cuore della cosa: una griglia di icone casuali si
/// risolve a colpo d'occhio, una dove ogni bersaglio ha un gemello quasi
/// identico obbliga a ricordare *quale* variante era e *in che posizione*.
///
/// Questo file è `domain/`: nessun import Flutter. I glifi sono id simbolici
/// (`'arrow_up'`); la mappa id → `IconData` vive in presentation
/// (`unlock_challenge_glyphs.dart`).
library;

import 'dart:math';

/// Famiglia di glifi **visivamente confondibili**: le varianti di una stessa
/// famiglia differiscono solo per rotazione, riempimento o spessore.
///
/// Invariante di generazione: i bersagli della sequenza vengono presi da
/// famiglie DIVERSE (così sono distinguibili fra loro), mentre i distrattori
/// vengono presi dalla STESSA famiglia dei bersagli (così la griglia è
/// difficile da scremare a colpo d'occhio).
class GlyphFamily {
  const GlyphFamily(this.id, this.variants);

  final String id;
  final List<String> variants;
}

/// Alfabeto dei glifi. Ogni entry è una famiglia di varianti confondibili.
///
/// Serve un margine ampio: al livello più alto la griglia è di 16 caselle e i
/// bersagli sono 5, quindi servono ≥5 famiglie con ≥3 varianti ciascuna più
/// famiglie di riempimento. Aggiungerne altre è sicuro; toglierne richiede di
/// ricontrollare [UnlockChallengeLevel.gridSize] (vedi [generateUnlockChallenge],
/// che alza un [StateError] se l'alfabeto non basta a riempire la griglia).
const List<GlyphFamily> kGlyphFamilies = [
  GlyphFamily('arrow', ['arrow_up', 'arrow_down', 'arrow_left', 'arrow_right']),
  GlyphFamily('chevron', [
    'chevron_up',
    'chevron_down',
    'chevron_left',
    'chevron_right',
  ]),
  GlyphFamily('star', ['star_full', 'star_empty', 'star_half', 'star_thin']),
  GlyphFamily('heart', ['heart_full', 'heart_empty', 'heart_broken']),
  GlyphFamily('circle', [
    'circle_full',
    'circle_empty',
    'circle_target',
    'circle_dot',
  ]),
  GlyphFamily('square', ['square_full', 'square_empty', 'square_thin']),
  GlyphFamily('triangle', [
    'triangle_empty',
    'triangle_right',
    'triangle_up',
    'triangle_down',
  ]),
  GlyphFamily('moon', ['moon_full', 'moon_tilt', 'moon_bed', 'moon_thin']),
  GlyphFamily('clock', [
    'clock_face',
    'clock_timer',
    'clock_sand_top',
    'clock_sand_bottom',
  ]),
  GlyphFamily('leaf', ['leaf_eco', 'leaf_spa', 'leaf_flower', 'leaf_tree']),
  GlyphFamily('bolt', ['bolt_plain', 'bolt_flash', 'bolt_circle']),
  GlyphFamily('drop', ['drop_full', 'drop_opacity', 'drop_invert']),
];

/// Quanto costa disattivare una protezione.
///
/// I parametri crescono su tre assi contemporaneamente (lunghezza della
/// sequenza, densità di distrattori, tempo di memorizzazione che si accorcia):
/// è quello che fa la differenza fra "seccatura" e "dosso vero".
enum UnlockChallengeLevel {
  /// Nessun attrito: la disattivazione è immediata (comportamento storico).
  off,

  /// 3 glifi, griglia 3×3, 5 secondi per memorizzare.
  gentle,

  /// 4 glifi, griglia 3×4, 4 secondi.
  standard,

  /// 5 glifi, griglia 4×4, 3 secondi.
  stubborn;

  /// Quanti glifi compongono la sequenza da ricostruire.
  int get sequenceLength => switch (this) {
    UnlockChallengeLevel.off => 0,
    UnlockChallengeLevel.gentle => 3,
    UnlockChallengeLevel.standard => 4,
    UnlockChallengeLevel.stubborn => 5,
  };

  /// Quante caselle ha la griglia della fase di ricostruzione.
  int get gridSize => switch (this) {
    UnlockChallengeLevel.off => 0,
    UnlockChallengeLevel.gentle => 9,
    UnlockChallengeLevel.standard => 12,
    UnlockChallengeLevel.stubborn => 16,
  };

  /// Colonne della griglia. `gridSize` è sempre divisibile per questo valore.
  int get columns => switch (this) {
    UnlockChallengeLevel.off => 0,
    UnlockChallengeLevel.gentle => 3,
    UnlockChallengeLevel.standard => 3,
    UnlockChallengeLevel.stubborn => 4,
  };

  /// Per quanto resta visibile la sequenza prima di sparire.
  Duration get memorizeDuration => switch (this) {
    UnlockChallengeLevel.off => Duration.zero,
    UnlockChallengeLevel.gentle => const Duration(seconds: 5),
    UnlockChallengeLevel.standard => const Duration(seconds: 4),
    UnlockChallengeLevel.stubborn => const Duration(seconds: 3),
  };

  bool get isActive => this != UnlockChallengeLevel.off;

  /// Etichetta breve per la UI delle impostazioni.
  String get label => switch (this) {
    UnlockChallengeLevel.off => 'Nessuna',
    UnlockChallengeLevel.gentle => 'Leggera',
    UnlockChallengeLevel.standard => 'Media',
    UnlockChallengeLevel.stubborn => 'Testarda',
  };

  String get description => switch (this) {
    UnlockChallengeLevel.off =>
      'Disattivare un profilo è immediato, come adesso.',
    UnlockChallengeLevel.gentle => '3 simboli, 5 secondi per memorizzarli.',
    UnlockChallengeLevel.standard => '4 simboli, 4 secondi, più distrattori.',
    UnlockChallengeLevel.stubborn =>
      '5 simboli, 3 secondi, griglia piena di sosia.',
  };

  /// Valore persistito su Hive. Salviamo il **nome** e non l'indice così
  /// riordinare o inserire un livello non ri-etichetta la scelta già salvata.
  String get storageValue => name;

  /// Inverso di [storageValue]. Qualsiasi valore ignoto (dato vecchio,
  /// scrittura corrotta) degrada a [off]: l'attrito è opt-in, non lo imponiamo
  /// mai per errore.
  static UnlockChallengeLevel fromStorage(String? value) {
    for (final level in UnlockChallengeLevel.values) {
      if (level.name == value) return level;
    }
    return UnlockChallengeLevel.off;
  }
}

/// Una sfida generata: la sequenza da ricordare e la griglia in cui ritrovarla.
class UnlockChallenge {
  const UnlockChallenge({
    required this.sequence,
    required this.grid,
    required this.columns,
    required this.memorizeDuration,
  });

  /// I glifi da toccare, **nell'ordine mostrato** nella fase di memorizzazione.
  final List<String> sequence;

  /// Le caselle della fase di ricostruzione: contiene tutti i glifi di
  /// [sequence] più i distrattori, mescolati. Ogni id compare **una volta
  /// sola** — altrimenti un tocco sarebbe ambiguo.
  final List<String> grid;

  final int columns;
  final Duration memorizeDuration;

  int get length => sequence.length;

  /// True se toccare [glyphId] è la mossa giusta avendo già indovinato
  /// [progress] glifi. Fuori range ⇒ false (non si può "sforare" la sequenza).
  bool isCorrectNext(int progress, String glyphId) =>
      progress >= 0 &&
      progress < sequence.length &&
      sequence[progress] == glyphId;
}

/// Costruisce una sfida per [level].
///
/// Algoritmo:
///  1. sceglie [UnlockChallengeLevel.sequenceLength] famiglie DIVERSE e ne
///     estrae un glifo ciascuna → è la sequenza (bersagli distinguibili fra
///     loro anche a memoria sfocata);
///  2. per ogni bersaglio aggiunge dei **sosia**: altre varianti della sua
///     stessa famiglia. È qui che nasce l'attrito;
///  3. riempie le caselle avanzate pescando dalle famiglie non usate;
///  4. mescola la griglia, così la disposizione spaziale non ha alcun rapporto
///     con l'ordine mostrato.
///
/// [random] è iniettabile per rendere i test deterministici.
///
/// Lancia [StateError] se [level] è [UnlockChallengeLevel.off] (non c'è nulla
/// da generare) o se [kGlyphFamilies] non contiene abbastanza glifi per
/// riempire la griglia richiesta.
UnlockChallenge generateUnlockChallenge(
  UnlockChallengeLevel level, {
  Random? random,
}) {
  if (!level.isActive) {
    throw StateError('generateUnlockChallenge chiamata con level=off');
  }

  final rng = random ?? Random.secure();
  final families = [...kGlyphFamilies]..shuffle(rng);

  if (families.length < level.sequenceLength) {
    throw StateError(
      'Servono almeno ${level.sequenceLength} famiglie di glifi, '
      'kGlyphFamilies ne ha ${families.length}',
    );
  }

  // 1. Bersagli: una famiglia ciascuno, variante a caso dentro la famiglia.
  final targetFamilies = families.take(level.sequenceLength).toList();
  final sequence = <String>[];
  // Varianti ancora libere per famiglia, da cui pescheremo i sosia al punto 2.
  final siblingPool = <String, List<String>>{};
  for (final family in targetFamilies) {
    final variants = [...family.variants]..shuffle(rng);
    sequence.add(variants.first);
    siblingPool[family.id] = variants.skip(1).toList();
  }

  // 2. Sosia: distribuiti a giro fra i bersagli (round-robin) invece che
  //    "tutti quelli della prima famiglia, poi la seconda". Così, quando le
  //    caselle non bastano per un sosia a testa, nessun bersaglio resta
  //    sistematicamente senza gemello — che sarebbe un indizio gratis.
  final decoys = <String>[];
  final slotsForDecoys = level.gridSize - level.sequenceLength;
  var exhausted = false;
  while (decoys.length < slotsForDecoys && !exhausted) {
    exhausted = true;
    for (final family in targetFamilies) {
      if (decoys.length >= slotsForDecoys) break;
      final pool = siblingPool[family.id]!;
      if (pool.isEmpty) continue;
      decoys.add(pool.removeAt(0));
      exhausted = false;
    }
  }

  // 3. Riempimento: se restano caselle, pesca dalle famiglie NON usate come
  //    bersaglio (una variante ciascuna, poi un secondo giro, ecc.).
  final fillerFamilies = families.skip(level.sequenceLength).toList();
  final fillerPool = <String>[];
  var depth = 0;
  while (decoys.length + fillerPool.length < slotsForDecoys) {
    final before = fillerPool.length;
    for (final family in fillerFamilies) {
      if (decoys.length + fillerPool.length >= slotsForDecoys) break;
      if (depth < family.variants.length) fillerPool.add(family.variants[depth]);
    }
    if (fillerPool.length == before) {
      throw StateError(
        'kGlyphFamilies non basta a riempire una griglia da '
        '${level.gridSize} caselle per il livello ${level.name}',
      );
    }
    depth++;
  }

  final grid = [...sequence, ...decoys, ...fillerPool]..shuffle(rng);

  return UnlockChallenge(
    sequence: List.unmodifiable(sequence),
    grid: List.unmodifiable(grid),
    columns: level.columns,
    memorizeDuration: level.memorizeDuration,
  );
}
