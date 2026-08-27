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
  // Le varianti di questa famiglia hanno tutte qualcosa DENTRO il quadrato, e
  // non è un vezzo estetico: un quadrato vuoto è identico al glifo `.notdef`
  // che il font disegna quando un'icona manca, e l'utente lo legge come un bug
  // del puzzle invece che come un simbolo da ricordare. Vedi `kGlyphIcons`.
  GlyphFamily('square', [
    'square_full',
    'square_check',
    'square_dash',
    'square_cross',
  ]),
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
/// **Non esiste un livello "nessuno".** La sfida si può alleggerire, non
/// spegnere: un attrito che si toglie con un tap è esattamente il tap che
/// l'utente farebbe nel momento dell'impulso, e la feature esisteva per
/// interromperlo. Chi vuole il minimo prende [gentle].
enum UnlockChallengeLevel {
  /// 3 glifi, griglia 3×3, 5 secondi per memorizzare.
  gentle,

  /// 4 glifi, griglia 3×4, 4 secondi.
  standard,

  /// 5 glifi, griglia 4×4, 3 secondi.
  stubborn;

  /// Quanti glifi compongono la sequenza da ricostruire.
  int get sequenceLength => switch (this) {
    UnlockChallengeLevel.gentle => 3,
    UnlockChallengeLevel.standard => 4,
    UnlockChallengeLevel.stubborn => 5,
  };

  /// Quante caselle ha la griglia della fase di ricostruzione.
  int get gridSize => switch (this) {
    UnlockChallengeLevel.gentle => 9,
    UnlockChallengeLevel.standard => 12,
    UnlockChallengeLevel.stubborn => 16,
  };

  /// Colonne della griglia. `gridSize` è sempre divisibile per questo valore.
  int get columns => switch (this) {
    UnlockChallengeLevel.gentle => 3,
    UnlockChallengeLevel.standard => 3,
    UnlockChallengeLevel.stubborn => 4,
  };

  /// Per quanto resta visibile la sequenza prima di sparire.
  Duration get memorizeDuration => switch (this) {
    UnlockChallengeLevel.gentle => const Duration(seconds: 5),
    UnlockChallengeLevel.standard => const Duration(seconds: 4),
    UnlockChallengeLevel.stubborn => const Duration(seconds: 3),
  };

  // Etichetta e descrizione per la UI NON stanno qui: sono testo tradotto e
  // questo file è `domain/` (nessun import Flutter, quindi nessun accesso a
  // `AppLocalizations`). Vivono in
  // `presentation/screens/settings/sub_screens/unlock_challenge_screen.dart`
  // come estensione su questo enum.

  /// Livello di chi non ha mai toccato l'impostazione: chi installa Koru la
  /// installa per mettersi dei limiti, quindi si parte da un attrito vero e lo
  /// si alleggerisce in Impostazioni → Sfida di sblocco, non il contrario.
  static const UnlockChallengeLevel fallback = UnlockChallengeLevel.standard;

  /// Valore persistito su Hive. Salviamo il **nome** e non l'indice così
  /// riordinare o inserire un livello non ri-etichetta la scelta già salvata.
  String get storageValue => name;

  /// Inverso di [storageValue].
  ///
  /// Valore assente (mai configurato) o irriconoscibile (dato vecchio,
  /// scrittura corrotta) ⇒ [fallback]: si degrada solo verso la direzione
  /// protettiva, come fa il resto dell'app quando non sa. Ci ricade anche il
  /// vecchio `'off'` salvato prima che il livello venisse tolto — chi aveva
  /// spento l'attrito se lo ritrova a [fallback], che è il punto della
  /// rimozione, non un effetto collaterale.
  static UnlockChallengeLevel fromStorage(String? value) {
    for (final level in UnlockChallengeLevel.values) {
      if (level.name == value) return level;
    }
    return fallback;
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

  /// La sequenza espressa come **indici di casella**, nell'ordine di tocco.
  ///
  /// È la forma che capisce il lato Kotlin: per lo strict mode è il native a
  /// scegliere quali caselle formano la sequenza, e la risposta gli torna
  /// indietro così. Funziona perché in [grid] ogni glifo compare una volta
  /// sola, quindi glifo e casella si corrispondono uno a uno.
  List<int> get sequenceSlots => [
    for (final glyphId in sequence) grid.indexOf(glyphId),
  ];
}

/// I glifi di una sfida, prima che vengano disposti in griglia: i bersagli in
/// ordine e tutto il resto (sosia + riempitivi) alla rinfusa.
typedef _GlyphSet = ({List<String> sequence, List<String> others});

/// Sceglie i glifi di una sfida. È il pezzo che rende il puzzle un puzzle:
///
///  1. sceglie [sequenceLength] famiglie DIVERSE e ne estrae un glifo ciascuna
///     → i bersagli (distinguibili fra loro anche a memoria sfocata);
///  2. per ogni bersaglio aggiunge dei **sosia**: altre varianti della sua
///     stessa famiglia. È qui che nasce l'attrito;
///  3. riempie le caselle avanzate pescando dalle famiglie non usate.
///
/// Non decide *dove* finiscono in griglia: quello cambia fra il puzzle locale
/// (posizioni a caso) e quello dello strict mode (posizioni scelte dal nativo).
///
/// Lancia [StateError] se [kGlyphFamilies] non basta per i parametri chiesti.
_GlyphSet _pickGlyphs({
  required int sequenceLength,
  required int gridSize,
  required Random rng,
}) {
  final families = [...kGlyphFamilies]..shuffle(rng);

  if (families.length < sequenceLength) {
    throw StateError(
      'Servono almeno $sequenceLength famiglie di glifi, '
      'kGlyphFamilies ne ha ${families.length}',
    );
  }

  // 1. Bersagli: una famiglia ciascuno, variante a caso dentro la famiglia.
  final targetFamilies = families.take(sequenceLength).toList();
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
  final others = <String>[];
  final slotsForOthers = gridSize - sequenceLength;
  var exhausted = false;
  while (others.length < slotsForOthers && !exhausted) {
    exhausted = true;
    for (final family in targetFamilies) {
      if (others.length >= slotsForOthers) break;
      final pool = siblingPool[family.id]!;
      if (pool.isEmpty) continue;
      others.add(pool.removeAt(0));
      exhausted = false;
    }
  }

  // 3. Riempimento: se restano caselle, pesca dalle famiglie NON usate come
  //    bersaglio (una variante ciascuna, poi un secondo giro, ecc.).
  final fillerFamilies = families.skip(sequenceLength).toList();
  var depth = 0;
  while (others.length < slotsForOthers) {
    final before = others.length;
    for (final family in fillerFamilies) {
      if (others.length >= slotsForOthers) break;
      if (depth < family.variants.length) others.add(family.variants[depth]);
    }
    if (others.length == before) {
      throw StateError(
        'kGlyphFamilies non basta a riempire una griglia da $gridSize caselle '
        'con $sequenceLength bersagli',
      );
    }
    depth++;
  }

  return (sequence: sequence, others: others);
}

/// Costruisce una sfida per [level], con i bersagli sparsi a caso in griglia.
///
/// È la variante **locale**, usata dove il gate è puramente Dart (profili):
/// generazione e verifica avvengono entrambe qui. Per lo strict mode serve
/// invece [buildUnlockChallengeForSlots], perché lì la sequenza la decide il
/// nativo.
///
/// [random] è iniettabile per rendere i test deterministici.
///
/// Lancia [StateError] se [kGlyphFamilies] non contiene abbastanza glifi.
UnlockChallenge generateUnlockChallenge(
  UnlockChallengeLevel level, {
  Random? random,
}) {
  final rng = random ?? Random.secure();
  final glyphs = _pickGlyphs(
    sequenceLength: level.sequenceLength,
    gridSize: level.gridSize,
    rng: rng,
  );
  final grid = [...glyphs.sequence, ...glyphs.others]..shuffle(rng);

  return UnlockChallenge(
    sequence: List.unmodifiable(glyphs.sequence),
    grid: List.unmodifiable(grid),
    columns: level.columns,
    memorizeDuration: level.memorizeDuration,
  );
}

/// Costruisce una sfida i cui bersagli finiscono nelle caselle [sequenceSlots],
/// in quell'ordine.
///
/// Serve allo strict mode: là la sequenza è scelta da Kotlin
/// (`StrictUnlockChallengeStore`) e arriva come indici di casella, perché è il
/// nativo a dover certificare la risposta — un gate scritto solo in Dart
/// verrebbe rifiutato da `setStrictModeOptions`. Il Dart resta comunque
/// padrone dell'estetica: quali simboli disegnare e quali sosia mettergli
/// accanto è deciso qui, e il Kotlin non sa nulla di icone.
///
/// Lancia [ArgumentError] se gli slot sono fuori griglia, duplicati o troppi:
/// una spec malformata deve rompersi subito e rumorosamente, non produrre un
/// puzzle irrisolvibile davanti all'utente.
UnlockChallenge buildUnlockChallengeForSlots({
  required int gridSize,
  required int columns,
  required Duration memorizeDuration,
  required List<int> sequenceSlots,
  Random? random,
}) {
  if (sequenceSlots.isEmpty || sequenceSlots.length > gridSize) {
    throw ArgumentError(
      'sequenceSlots (${sequenceSlots.length}) non sta in una griglia da '
      '$gridSize caselle',
    );
  }
  if (sequenceSlots.toSet().length != sequenceSlots.length) {
    throw ArgumentError('sequenceSlots contiene caselle ripetute: $sequenceSlots');
  }
  if (sequenceSlots.any((slot) => slot < 0 || slot >= gridSize)) {
    throw ArgumentError('sequenceSlots fuori dalla griglia: $sequenceSlots');
  }

  final rng = random ?? Random.secure();
  final glyphs = _pickGlyphs(
    sequenceLength: sequenceSlots.length,
    gridSize: gridSize,
    rng: rng,
  );

  final grid = List<String?>.filled(gridSize, null);
  for (var i = 0; i < sequenceSlots.length; i++) {
    grid[sequenceSlots[i]] = glyphs.sequence[i];
  }
  final others = [...glyphs.others]..shuffle(rng);
  var next = 0;
  for (var slot = 0; slot < gridSize; slot++) {
    grid[slot] ??= others[next++];
  }

  return UnlockChallenge(
    sequence: List.unmodifiable(glyphs.sequence),
    grid: List.unmodifiable(grid.cast<String>()),
    columns: columns,
    memorizeDuration: memorizeDuration,
  );
}
