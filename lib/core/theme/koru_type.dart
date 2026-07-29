import 'package:flutter/widgets.dart';

/// Tipografia del launcher "Inchiostro e ore": due famiglie, nessun'altra.
///
/// - **Instrument Serif** — l'inchiostro. Ore, preferiti, nomi delle app,
///   lettera fantasma. Le app sono *parole su una pagina*, non righe di una
///   lista: è questo che toglie al launcher l'aria da lista di sistema.
/// - **DM Mono** — la meta. Etichette in maiuscoletto spaziato: fascia oraria,
///   conteggi, TEL/CAM, tasti del rail A-Z.
///
/// Sono **fisse**, indipendenti dal font scelto dall'utente nelle Settings
/// (stesso patto che l'orologio aveva con Orbitron): la composizione del
/// launcher è parte dell'identità, non una preferenza.
abstract final class KoruType {
  const KoruType._();

  static const String serifFamily = 'InstrumentSerif';
  static const String monoFamily = 'DMMono';

  /// Serif editoriale. [letterSpacingEm] e [height] sono espressi come nel
  /// design (`em` e moltiplicatore di line-height), non in px.
  static TextStyle serif({
    required double size,
    required Color color,
    double height = 1,
    double letterSpacingEm = 0,
    double opacity = 1,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacingEm == 0 ? null : size * letterSpacingEm,
      color: opacity >= 1 ? color : color.withValues(alpha: opacity),
      fontStyle: fontStyle,
    );
  }

  /// Mono in maiuscoletto spaziato. [trackEm] arriva tipicamente da
  /// `LauncherPhase.trackEm` — è il "respiro" che cambia fra giorno e notte.
  static TextStyle mono({
    required double size,
    required Color color,
    double trackEm = 0,
    FontWeight weight = FontWeight.w400,
    double opacity = 1,
    double height = 1.2,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: trackEm == 0 ? null : size * trackEm,
      color: opacity >= 1 ? color : color.withValues(alpha: opacity),
    );
  }
}
