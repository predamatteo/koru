import 'package:flutter/animation.dart';

/// Movimento del launcher "Inchiostro e ore": esiste **solo sotto il dito**.
///
/// A riposo il launcher non disegna un frame — niente loop, niente ticker,
/// niente `AnimationController` in corsa. L'elastico sta nella *curva* del
/// rientro, non in una simulazione che gira: un `animateTo` con [settle] e
/// basta.
abstract final class LauncherMotion {
  const LauncherMotion._();

  /// Rientro con inerzia elastica. Il controllo `y` supera 1 di poco: la
  /// destinazione viene scavalcata e ripresa, senza spring simulato.
  static const Curve settle = Cubic(0.16, 1.02, 0.24, 1);

  /// [settle] senza sfondamento. Serve dove il 2% di overshoot scoprirebbe un
  /// bordo invece di leggersi come elasticità: una pagina che sale a coprire
  /// lo schermo, oltre il traguardo, lascerebbe una fessura in basso.
  static const Curve settleClamped = _ClampedCurve(settle);

  static const Duration settleDuration = Duration(milliseconds: 420);

  /// Quanti px di trascinamento verso l'alto portano lo srotolamento da 0 a 1.
  static const double unfurlDistance = 170;

  /// Oltre questa frazione, al rilascio il drawer si apre invece di rientrare.
  static const double unfurlCommit = 0.42;

  /// Quanto la home si solleva e rimpicciolisce mentre il drawer sale.
  static const double homeLift = 22;
  static const double homeScale = 0.03;
  static const double homeFade = 0.55;

  /// Trascinamento orizzontale necessario perché la hairline del lato sia
  /// completamente accesa.
  static const double hairlineFullLit = 90;

  /// Altezza a riposo / massima delle hairline laterali.
  static const double hairlineHeight = 64;
  static const double hairlineStretch = 40;
}

class _ClampedCurve extends Curve {
  const _ClampedCurve(this.inner);

  final Curve inner;

  @override
  double transformInternal(double t) => inner.transform(t).clamp(0.0, 1.0);
}
