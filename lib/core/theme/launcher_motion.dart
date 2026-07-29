import 'package:flutter/animation.dart';

/// Movimento del launcher: esiste **solo sotto il dito**.
///
/// A riposo il launcher non disegna un frame — niente loop, niente ticker,
/// niente `AnimationController` in corsa. Quando il dito c'è, la curva è
/// quella *emphasized* di Material 3: accelerazione decisa e frenata lunga,
/// la stessa che il resto del sistema usa per le transizioni di superficie.
abstract final class LauncherMotion {
  const LauncherMotion._();

  /// M3 "emphasized" easing. Monotona (nessuno sfondamento), quindi si può
  /// usare anche dove un overshoot scoprirebbe il bordo dello schermo — come
  /// il drawer che sale a coprire il launcher.
  static const Curve settle = Curves.easeInOutCubicEmphasized;

  /// M3 "long2": la durata delle transizioni che coinvolgono un'intera
  /// superficie.
  static const Duration settleDuration = Duration(milliseconds: 450);

  /// Quanti px di trascinamento verso l'alto portano l'apertura da 0 a 1.
  static const double unfurlDistance = 170;

  /// Oltre questa frazione, al rilascio il drawer si apre invece di rientrare.
  static const double unfurlCommit = 0.42;

  /// Quanto la home arretra mentre il drawer sale.
  static const double homeLift = 22;
  static const double homeScale = 0.03;
  static const double homeFade = 0.55;

  /// Trascinamento orizzontale necessario perché l'indicatore di bordo sia
  /// completamente acceso.
  static const double edgeFullLit = 90;

  /// Indicatore di swipe laterale: pastiglia stadium, non filetto da 1px.
  static const double edgeWidth = 3;
  static const double edgeHeight = 56;
  static const double edgeStretch = 40;
}
