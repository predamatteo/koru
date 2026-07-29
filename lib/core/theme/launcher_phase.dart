import 'dart:async';

import 'package:flutter/widgets.dart';

import '../constants/koru_colors.dart';

/// Fascia oraria del launcher "Inchiostro e ore".
///
/// Il launcher deriva la propria **luce** dall'ora: palette, spaziatura e peso
/// della tipografia cambiano fra giorno e notte. Le fasce sono **due, non
/// quattro** — in una giornata l'utente vede due stati e *un* accento per
/// volta.
///
/// Nessuna tinta nuova: le superfici e l'outline pescano dalla scala tonale
/// che [KoruColors] ha già (`bg · s1 · s2 · s3 · outline`), e l'accento si
/// sposta fra i due che Koru ha già — sage [KoruColors.primary] di giorno,
/// sand [KoruColors.tertiary] di notte. L'unica libertà è attenuare il testo
/// di notte ([KoruColors.textPrimaryDimmed] / [KoruColors.textSecondaryDimmed]).
///
/// Cambia la superficie di un gradino (`s1 → bg`), il testo si attenua, il
/// respiro si allarga: nient'altro.
enum LauncherPhase {
  /// 07:00 – 19:59. Superficie di un gradino sopra il fondo, contrasto pieno,
  /// righe più vicine, accento sage.
  day(
    label: 'DAY',
    background: KoruColors.surface,
    ink: KoruColors.textPrimary,
    ink2: KoruColors.textSecondary,
    hair: KoruColors.outline,
    accent: KoruColors.primary,
    trackEm: 0.12,
    gap: 22,
    clockOpacity: 1,
  ),

  /// 20:00 – 06:59. Il fondo più scuro che Koru ha, testo attenuato, orologio
  /// al 78%, respiro largo, accento sand (più caldo e meno sveglio del sage).
  night(
    label: 'NIGHT',
    background: KoruColors.backgroundBase,
    ink: KoruColors.textPrimaryDimmed,
    ink2: KoruColors.textSecondaryDimmed,
    hair: KoruColors.surfaceElevated,
    accent: KoruColors.tertiary,
    trackEm: 0.20,
    gap: 30,
    clockOpacity: 0.78,
  );

  const LauncherPhase({
    required this.label,
    required this.background,
    required this.ink,
    required this.ink2,
    required this.hair,
    required this.accent,
    required this.trackEm,
    required this.gap,
    required this.clockOpacity,
  });

  /// Etichetta mostrata nella riga meta sotto l'orologio.
  final String label;

  /// Fondo dello schermo (`--bg`).
  final Color background;

  /// Testo primario (`--ink`): orologio, preferiti, nomi app.
  final Color ink;

  /// Testo secondario (`--ink2`): meta, etichette mono, rail A-Z.
  final Color ink2;

  /// Hairline (`--hair`): i filetti da 1px — bordi laterali, separatori.
  final Color hair;

  /// Accento (`--acc`): uno solo per fascia. Spirale, caret, match di ricerca.
  final Color accent;

  /// Letter-spacing delle etichette mono, in `em` (`--track`). Va moltiplicato
  /// per la font-size — vedi `KoruType.mono`.
  final double trackEm;

  /// Respiro verticale fra i preferiti, in px logici (`--gap`).
  final double gap;

  /// Opacità dell'orologio (`--clockop`): pieno di giorno, 78% di notte.
  final double clockOpacity;

  /// Prima ora della fascia [day] (inclusa).
  static const int dayStartHour = 7;

  /// Prima ora della fascia [night] (inclusa).
  static const int nightStartHour = 20;

  static LauncherPhase forHour(int hour) =>
      hour >= dayStartHour && hour < nightStartHour ? day : night;

  static LauncherPhase at(DateTime t) => forHour(t.hour);

  /// Istante del prossimo cambio di fascia dopo [from]. Usato da
  /// [LauncherPhaseBuilder] per schedulare **un solo** timer al confine
  /// invece di svegliarsi ogni minuto.
  static DateTime nextBoundary(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    if (from.hour < dayStartHour) {
      return today.add(const Duration(hours: dayStartHour));
    }
    if (from.hour < nightStartHour) {
      return today.add(const Duration(hours: nightStartHour));
    }
    // Aritmetica su Duration (non `day + 1`) così un cambio DST sposta il
    // confine invece di saltarlo o ripeterlo.
    return today.add(const Duration(hours: 24 + dayStartHour));
  }
}

/// Ricostruisce [builder] con la [LauncherPhase] corrente, e **una sola volta**
/// per cambio di fascia.
///
/// Il launcher a riposo non deve disegnare frame: qui non c'è nessun loop né
/// tick al minuto — un unico [Timer] armato sul prossimo confine
/// ([LauncherPhase.nextBoundary]), che al massimo scatta due volte al giorno.
class LauncherPhaseBuilder extends StatefulWidget {
  const LauncherPhaseBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, LauncherPhase phase) builder;

  @override
  State<LauncherPhaseBuilder> createState() => _LauncherPhaseBuilderState();
}

class _LauncherPhaseBuilderState extends State<LauncherPhaseBuilder>
    with WidgetsBindingObserver {
  Timer? _timer;
  LauncherPhase _phase = LauncherPhase.at(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // I Timer non avanzano in modo affidabile mentre il processo è sospeso:
    // al rientro ricalcoliamo la fascia invece di fidarci della schedulazione.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    var delay = LauncherPhase.nextBoundary(now).difference(now);
    // Guardia su orologio spostato all'indietro / confine già passato.
    if (delay <= Duration.zero) delay = const Duration(minutes: 1);
    _timer = Timer(delay, _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    final next = LauncherPhase.at(DateTime.now());
    if (next != _phase) setState(() => _phase = next);
    _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _phase);
}
