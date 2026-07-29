import 'dart:async';

import 'package:flutter/widgets.dart';

import '../constants/koru_colors.dart';

/// Fascia oraria del launcher.
///
/// Il launcher deriva la propria **luce** dall'ora: cambia la superficie di un
/// gradino, l'accento e il respiro fra le righe. Le fasce sono **due, non
/// quattro** — in una giornata l'utente vede due stati e *un* accento per
/// volta.
///
/// Nessuna tinta dedicata: ogni valore qui sotto è un token che [KoruColors]
/// ha già. Le superfici pescano dalla scala tonale (`bg · s1 · s3 · outline`)
/// e l'accento si sposta fra i due che l'app usa ovunque — sage
/// [KoruColors.primary] di giorno, sand [KoruColors.tertiary] di notte, con i
/// rispettivi container Material 3 per i bottoni tonali.
///
/// Il testo NON cambia colore fra le fasce: resta `textPrimary` /
/// `textSecondary` come nel resto dell'app. L'unica attenuazione è
/// [clockOpacity] sull'orologio.
enum LauncherPhase {
  /// 07:00 – 19:59. Superficie di un gradino sopra il fondo, righe più
  /// vicine, accento sage.
  day(
    background: KoruColors.surface,
    accent: KoruColors.primary,
    accentContainer: KoruColors.primaryContainer,
    onAccentContainer: KoruColors.onPrimaryContainer,
    edge: KoruColors.outline,
    gap: 22,
    clockOpacity: 1,
  ),

  /// 20:00 – 06:59. Il fondo più scuro che Koru ha, respiro largo, orologio
  /// al 78%, accento sand (più caldo e meno sveglio del sage).
  night(
    background: KoruColors.backgroundBase,
    accent: KoruColors.tertiary,
    accentContainer: KoruColors.tertiaryContainer,
    onAccentContainer: KoruColors.onTertiaryContainer,
    edge: KoruColors.surfaceElevated,
    gap: 30,
    clockOpacity: 0.78,
  );

  const LauncherPhase({
    required this.background,
    required this.accent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.edge,
    required this.gap,
    required this.clockOpacity,
  });

  /// Fondo dello schermo.
  final Color background;

  /// Accento della fascia: uno solo per volta. Maniglia, caret, match di
  /// ricerca, intestazioni di sezione.
  final Color accent;

  /// Container tonale M3 dell'accento — sfondo dei bottoni tonali (chip
  /// schede aperte, pastiglia Koru).
  final Color accentContainer;

  /// Contenuto sopra [accentContainer].
  final Color onAccentContainer;

  /// Colore dei bordi/indicatori sottili (indicatori di swipe laterali,
  /// separatore della barra di ricerca).
  final Color edge;

  /// Respiro verticale fra i preferiti, in px logici.
  final double gap;

  /// Opacità dell'orologio: pieno di giorno, attenuato di notte.
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
