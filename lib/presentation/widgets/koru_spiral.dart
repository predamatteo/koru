import 'package:flutter/widgets.dart';

/// La spirale koru — **l'affordance, non un logo**.
///
/// Compare in due posti del launcher, con lo stesso tratto:
/// - in alto a destra, srotolata al 100%, come scorciatoia a Koru;
/// - in basso al centro, come *maniglia* del drawer: si srotola col dito
///   mentre trascini verso l'alto ([progress]) e diventa il gesto.
///
/// Il tracciato è una polilinea in un riquadro 0-100 (lo stesso viewBox del
/// design): [strokeWidth] è quindi espresso in unità di quel riquadro e
/// scalato con la figura, così il tratto resta proporzionato a ogni [size].
class KoruSpiral extends StatelessWidget {
  const KoruSpiral({
    required this.size,
    required this.color,
    this.progress = 1,
    this.strokeWidth = 4.5,
    super.key,
  });

  /// Lato del quadrato in cui la spirale è disegnata (px logici).
  final double size;

  final Color color;

  /// Quanta parte del tracciato è disegnata, `0` = solo il ricciolo interno,
  /// `1` = spirale completa. Vedi [unfurl].
  final double progress;

  /// Spessore del tratto in unità del riquadro 0-100.
  final double strokeWidth;

  /// Mappa l'avanzamento del drag (`0` a dito fermo, `1` a drawer aperto) sulla
  /// frazione di spirale disegnata. A riposo la spirale non è mai vuota: resta
  /// il 45% arrotolato, e il gesto la porta al 100%.
  static double unfurl(double dragProgress) => 1 - 0.55 * (1 - dragProgress);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KoruSpiralPainter(
          color: color,
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _KoruSpiralPainter extends CustomPainter {
  const _KoruSpiralPainter({
    required this.color,
    required this.progress,
    required this.strokeWidth,
  });

  final Color color;
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final scale = size.shortestSide / 100;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(_partialPath(progress), paint);
    canvas.restore();
  }

  /// Il tratto disegnato parte dal centro del ricciolo e si srotola verso
  /// l'esterno — l'equivalente di `stroke-dashoffset` sull'SVG del design.
  Path _partialPath(double fraction) {
    if (fraction >= 1) return _fullPath;
    final metric = _fullPath.computeMetrics().first;
    return metric.extractPath(0, metric.length * fraction);
  }

  @override
  bool shouldRepaint(_KoruSpiralPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;

  static final Path _fullPath = () {
    final p = Path()..moveTo(_points.first.dx, _points.first.dy);
    for (var i = 1; i < _points.length; i++) {
      p.lineTo(_points[i].dx, _points[i].dy);
    }
    return p;
  }();
}

/// Campionamento della spirale koru in un riquadro 0-100, dal ricciolo interno
/// (primo punto) alla punta esterna (ultimo). Preso 1:1 dal design.
const List<Offset> _points = [
  Offset(50.00, 48.40), Offset(50.23, 48.36), Offset(50.47, 48.36),
  Offset(50.72, 48.39), Offset(50.97, 48.46), Offset(51.22, 48.56),
  Offset(51.46, 48.70), Offset(51.68, 48.89), Offset(51.88, 49.10),
  Offset(52.06, 49.35), Offset(52.20, 49.64), Offset(52.30, 49.95),
  Offset(52.36, 50.28), Offset(52.38, 50.63), Offset(52.34, 50.99),
  Offset(52.25, 51.35), Offset(52.11, 51.71), Offset(51.91, 52.06),
  Offset(51.66, 52.38), Offset(51.35, 52.68), Offset(51.00, 52.94),
  Offset(50.59, 53.15), Offset(50.15, 53.31), Offset(49.68, 53.41),
  Offset(49.17, 53.44), Offset(48.66, 53.40), Offset(48.13, 53.29),
  Offset(47.61, 53.09), Offset(47.11, 52.82), Offset(46.63, 52.46),
  Offset(46.19, 52.03), Offset(45.81, 51.53), Offset(45.49, 50.96),
  Offset(45.25, 50.33), Offset(45.09, 49.65), Offset(45.02, 48.93),
  Offset(45.06, 48.18), Offset(45.21, 47.42), Offset(45.47, 46.67),
  Offset(45.85, 45.93), Offset(46.34, 45.24), Offset(46.95, 44.59),
  Offset(47.66, 44.02), Offset(48.47, 43.55), Offset(49.37, 43.17),
  Offset(50.35, 42.92), Offset(51.38, 42.81), Offset(52.46, 42.84),
  Offset(53.55, 43.03), Offset(54.65, 43.38), Offset(55.71, 43.90),
  Offset(56.73, 44.58), Offset(57.68, 45.43), Offset(58.52, 46.44),
  Offset(59.23, 47.59), Offset(59.80, 48.87), Offset(60.19, 50.27),
  Offset(60.39, 51.75), Offset(60.38, 53.30), Offset(60.15, 54.88),
  Offset(59.68, 56.46), Offset(58.96, 58.02), Offset(58.01, 59.51),
  Offset(56.82, 60.89), Offset(55.40, 62.13), Offset(53.77, 63.20),
  Offset(51.94, 64.06), Offset(49.95, 64.67), Offset(47.82, 65.00),
  Offset(45.60, 65.04), Offset(43.32, 64.75), Offset(41.02, 64.13),
  Offset(38.76, 63.16), Offset(36.59, 61.84), Offset(34.56, 60.17),
  Offset(32.73, 58.17), Offset(31.14, 55.86), Offset(29.85, 53.26),
  Offset(28.90, 50.41), Offset(28.35, 47.37), Offset(28.22, 44.17),
  Offset(28.56, 40.87), Offset(29.38, 37.55), Offset(30.70, 34.27),
  Offset(32.53, 31.10), Offset(34.86, 28.13), Offset(37.68, 25.42),
  Offset(40.95, 23.06), Offset(44.65, 21.12), Offset(48.71, 19.67),
  Offset(53.08, 18.77), Offset(57.67, 18.49), Offset(62.42, 18.86),
  Offset(67.23, 19.93), Offset(71.99, 21.73), Offset(76.60, 24.25),
  Offset(80.96, 27.51),
];
