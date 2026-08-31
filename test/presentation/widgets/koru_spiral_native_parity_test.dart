import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/koru_colors.dart';

/// Guardrail del marchio nativo, nello spirito di `db_schema_contract_test` e
/// di `arb_parity_test`: tiene insieme file che devono dire la stessa cosa e
/// che nessun compilatore confronta fra loro.
///
/// La spirale koru è disegnata **tre volte**: da `_KoruSpiralPainter` dentro
/// Flutter, e da due `VectorDrawable` fuori da Flutter — lo splash di sistema
/// (Android 12+) e il foreground dell'icona adattiva. I due vector non possono
/// leggere il codice Dart: girano prima che il processo Flutter esista, o
/// dentro il launcher di sistema. Ritoccare la polilinea in Dart e lasciare
/// indietro i vector non rompe nulla in compilazione — cambia solo l'icona che
/// l'utente vede, in silenzio.
///
/// Il test confronta i numeri uno a uno, ed è il motivo per cui i vector
/// tengono le coordinate 0-100 identiche a quelle Dart e affidano il fitting
/// alle trasformazioni del `<group>`.
void main() {
  const dartSource = 'lib/presentation/widgets/koru_spiral.dart';
  const resDir = 'android/app/src/main/res';

  String read(String path) => File(path).readAsStringSync();

  /// I punti della polilinea, come coppie (x, y) arrotondate a 2 decimali.
  ///
  /// Sia in Dart (`Offset(50.00, 48.40)`) sia nel pathData del vector
  /// (`M50.00,48.40 L50.23,48.36 …`) i numeri sono gli stessi, quindi basta
  /// una sola regola di estrazione per entrambi.
  List<(double, double)> pointsOf(String source, RegExp pattern) => pattern
      .allMatches(source)
      .map((m) => (
            double.parse(m.group(1)!),
            double.parse(m.group(2)!),
          ))
      .toList();

  double attr(String xml, String name) {
    final m = RegExp('android:$name="([-\\d.]+)"').firstMatch(xml);
    expect(m, isNotNull, reason: 'attributo android:$name assente');
    return double.parse(m!.group(1)!);
  }

  int colorAttr(String xml, String name) {
    final m = RegExp('android:$name="#([0-9A-Fa-f]{8})"').firstMatch(xml);
    expect(m, isNotNull, reason: 'attributo android:$name assente o non #AARRGGBB');
    return int.parse(m!.group(1)!, radix: 16);
  }

  // ── La sorgente di verità: il painter Dart ─────────────────────────────
  final dart = read(dartSource);
  final dartPoints = pointsOf(
    dart.substring(dart.indexOf('const List<Offset> _points')),
    RegExp(r'Offset\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)'),
  );
  final dartStroke = double.parse(
    RegExp(r'this\.strokeWidth\s*=\s*([\d.]+)').firstMatch(dart)!.group(1)!,
  );

  final minX = dartPoints.map((p) => p.$1).reduce(math.min);
  final maxX = dartPoints.map((p) => p.$1).reduce(math.max);
  final minY = dartPoints.map((p) => p.$2).reduce(math.min);
  final maxY = dartPoints.map((p) => p.$2).reduce(math.max);
  // Il tratto deborda di metà spessore per lato: entra nell'ingombro, come in
  // `_KoruSpiralPainter.paint`.
  final glyphWidth = maxX - minX + dartStroke;
  final glyphHeight = maxY - minY + dartStroke;
  final glyphDiagonal =
      math.sqrt(glyphWidth * glyphWidth + glyphHeight * glyphHeight);
  final glyphCenter = ((minX + maxX) / 2, (minY + maxY) / 2);

  /// I due vector e la keyline che ciascuno deve rispettare.
  ///
  /// - splash senza icon background: riquadro 288 dp, glifo entro un cerchio
  ///   di 192 dp;
  /// - foreground adattivo: riquadro 108 dp, di cui il sistema garantisce
  ///   visibile solo il quadrato centrale 72x72 (maschera circolare Ø 72).
  const vectors = <String, ({String path, double canvas, double keyline})>{
    'splash di sistema': (
      path: '$resDir/drawable/ic_koru_splash.xml',
      canvas: 288,
      keyline: 192,
    ),
    'foreground icona adattiva': (
      path: '$resDir/drawable/ic_launcher_foreground.xml',
      canvas: 108,
      keyline: 72,
    ),
  };

  group('parità del marchio fra Dart e VectorDrawable', () {
    test('il painter Dart espone la polilinea attesa', () {
      // Se questo salta, non è un problema di parità: è la regex di lettura
      // che non trova più i punti, e tutti gli altri test qui sotto starebbero
      // confrontando liste vuote.
      expect(dartPoints, hasLength(greaterThan(50)));
      expect(dartStroke, greaterThan(0));
    });

    for (final entry in vectors.entries) {
      final name = entry.key;
      final spec = entry.value;

      group(name, () {
        final xml = read(spec.path);
        final vectorPoints = pointsOf(
          RegExp(r'android:pathData="([^"]*)"', dotAll: true)
              .firstMatch(xml)!
              .group(1)!,
          RegExp(r'[ML]\s*([\d.]+),([\d.]+)'),
        );

        test('stesso numero di punti del painter Dart', () {
          expect(vectorPoints, hasLength(dartPoints.length));
        });

        test('stesse coordinate, punto per punto', () {
          for (var i = 0; i < dartPoints.length; i++) {
            expect(
              vectorPoints[i],
              dartPoints[i],
              reason: 'punto $i divergente: rigenera ${spec.path} '
                  'dai punti di $dartSource',
            );
          }
        });

        test('stesso spessore di tratto del painter Dart', () {
          // Lo `<group>` scala anche il tratto, quindi tenerlo uguale in unità
          // 0-100 mantiene identico il rapporto tratto/spirale a ogni misura.
          expect(attr(xml, 'strokeWidth'), dartStroke);
        });

        test('il glifo è centrato nel riquadro', () {
          // Nel riquadro 0-100 il bounding box è decentrato in alto a destra:
          // senza la traslazione giusta l'icona risulta storta dentro la
          // maschera del sistema. Stessa correzione che il painter Dart fa
          // con `_bounds.center`.
          final scale = attr(xml, 'scaleX');
          expect(attr(xml, 'scaleY'), scale, reason: 'scala non uniforme');

          final cx = scale * glyphCenter.$1 + attr(xml, 'translateX');
          final cy = scale * glyphCenter.$2 + attr(xml, 'translateY');
          expect(cx, closeTo(spec.canvas / 2, 0.05));
          expect(cy, closeTo(spec.canvas / 2, 0.05));
        });

        test('il glifo sta dentro la keyline di ${spec.keyline.toInt()} dp',
            () {
          final scale = attr(xml, 'scaleX');
          final diagonal = glyphDiagonal * scale;

          expect(
            diagonal,
            lessThanOrEqualTo(spec.keyline),
            reason: 'il marchio sborda dalla keyline: il sistema lo taglia',
          );
          // L'altro lato dell'errore: una scala troppo piccola non taglia
          // nulla e non fa fallire niente, si vede solo come un francobollo
          // perso in mezzo allo splash.
          expect(
            diagonal,
            greaterThanOrEqualTo(spec.keyline * 0.85),
            reason: 'il marchio è molto più piccolo della keyline',
          );
        });

        test('è disegnato con il salvia di KoruColors.primary', () {
          expect(colorAttr(xml, 'strokeColor'), KoruColors.primary.toARGB32());
        });
      });
    }
  });

  group('icona di notifica', () {
    // L'unica incarnazione del marchio che NON usa tutti i punti: a 24 dp il
    // ricciolo interno si chiude in una macchia, quindi il tracciato parte più
    // in fuori e il tratto è più pesante. È correzione ottica, e la differenza
    // va tenuta stretta — altrimenti "icona più leggibile" diventa la scusa
    // per un secondo marchio che nessuno ha disegnato.
    const path = '$resDir/drawable/ic_notification_koru.xml';
    const canvas = 24.0;
    final xml = read(path);
    final points = pointsOf(
      RegExp(r'android:pathData="([^"]*)"', dotAll: true)
          .firstMatch(xml)!
          .group(1)!,
      RegExp(r'[ML]\s*([\d.]+),([\d.]+)'),
    );

    test('il tracciato è un suffisso esatto dei punti Dart', () {
      final start = dartPoints.indexOf(points.first);
      expect(start, greaterThanOrEqualTo(0),
          reason: 'il primo punto non esiste in $dartSource');
      expect(
        points,
        dartPoints.sublist(start),
        reason: 'non è la spirale di Koru accorciata, è un altro disegno',
      );
    });

    test('accorcia solo il ricciolo interno', () {
      // Tolto troppo, resta un uncino che non si legge più come una spirale.
      final dropped = dartPoints.length - points.length;
      expect(dropped, lessThanOrEqualTo(dartPoints.length ~/ 3));
      expect(dropped, greaterThan(0), reason: 'se non toglie nulla, usa lo '
          'stesso vector del launcher invece di duplicarlo');
    });

    test('il tratto reso pesa quanto un\'icona di sistema Material', () {
      // ~2 dp su 24: sotto sparisce nella status bar, sopra impasta le
      // spire. È il numero che giustifica l'esistenza di questo file.
      final rendered = attr(xml, 'strokeWidth') * attr(xml, 'scaleX');
      expect(rendered, greaterThanOrEqualTo(1.8));
      expect(rendered, lessThanOrEqualTo(2.4));
    });

    test('il glifo è centrato e sta nel riquadro', () {
      final stroke = attr(xml, 'strokeWidth');
      final scale = attr(xml, 'scaleX');
      expect(attr(xml, 'scaleY'), scale, reason: 'scala non uniforme');

      final xs = points.map((p) => p.$1);
      final ys = points.map((p) => p.$2);
      final cx = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
      final cy = (ys.reduce(math.min) + ys.reduce(math.max)) / 2;
      expect(scale * cx + attr(xml, 'translateX'), closeTo(canvas / 2, 0.05));
      expect(scale * cy + attr(xml, 'translateY'), closeTo(canvas / 2, 0.05));

      final w = (xs.reduce(math.max) - xs.reduce(math.min) + stroke) * scale;
      final h = (ys.reduce(math.max) - ys.reduce(math.min) + stroke) * scale;
      expect(math.max(w, h), lessThanOrEqualTo(canvas));
      expect(math.max(w, h), greaterThanOrEqualTo(canvas * 0.8),
          reason: 'un glifo piccolo dentro un riquadro grande si vede come '
              'un puntino nella status bar');
    });

    test('è bianco pieno', () {
      // Da API 21 la small icon è trattata come maschera di alfa: qualunque
      // colore verrebbe scartato, e uno colorato illude chi legge il file.
      expect(colorAttr(xml, 'strokeColor'), 0xFFFFFFFF);
    });

    test('nessuna notifica usa più icone di sistema', () {
      // Il punto di partenza: lucchetto e triangolo generici, che nella status
      // bar non dicono da quale app arriva la notifica.
      final kotlin = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.kt'));

      final offenders = <String>[];
      for (final file in kotlin) {
        final source = file.readAsStringSync();
        if (RegExp(r'setSmallIcon\(\s*android\.R\.drawable').hasMatch(source)) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('risorse di lancio', () {
    // Due trappole di risoluzione delle risorse Android, entrambe già scattate
    // in questo repo: un file con un qualificatore più specifico oscura quello
    // che si sta modificando, e non c'è alcun errore a dirlo.
    test('nessun drawable qualificato oscura launch_background', () {
      // `drawable-v21/launch_background.xml` (il template di Flutter) vinceva
      // su OGNI device, visto che minSdk = 28: il launch_background di Koru
      // non è mai stato quello mostrato.
      final shadowing = Directory(resDir)
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.replaceAll(r'\', '/'))
          .where((p) => p.contains('/drawable-'))
          .where((p) => File('$p/launch_background.xml').existsSync())
          .toList();

      expect(
        shadowing,
        isEmpty,
        reason: 'launch_background.xml deve stare solo in res/drawable/',
      );
    });

    test('nessuno styles.xml in night mode oscura values-v31', () {
      // Il qualificatore di night mode ha precedenza su quello di versione:
      // un values-night/styles.xml vincerebbe su values-v31/styles.xml e su un
      // device in tema scuro lo splash tornerebbe senza marchio.
      expect(
        File('$resDir/values-night/styles.xml').existsSync(),
        isFalse,
        reason: 'se serve, aggiungere anche values-night-v31/styles.xml',
      );
    });

    test('lo splash di sistema dichiara sfondo e icona di Koru', () {
      final styles = read('$resDir/values-v31/styles.xml');
      expect(styles, contains('android:windowSplashScreenBackground'));
      expect(styles, contains('@drawable/ic_koru_splash'));
    });

    test('i colori nativi del lancio rispecchiano KoruColors', () {
      final colors = read('$resDir/values/colors.xml');

      int token(String name) => int.parse(
            RegExp('<color name="$name">#([0-9A-Fa-f]{8})</color>')
                .firstMatch(colors)!
                .group(1)!,
            radix: 16,
          );

      expect(token('koru_background_base'), KoruColors.backgroundBase.toARGB32());
      expect(token('koru_icon_background'), KoruColors.primaryContainer.toARGB32());
    });
  });
}
