import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../providers/battery_provider.dart';

/// Orologio minimalista per il launcher: ora + data + indicatore batteria
/// discreto sotto. Senza cornice circolare — estetica pulita e centrata.
///
/// Il font dei numeri è fisso su Orbitron per un look "digital" distintivo,
/// indipendente dalla scelta globale dell'utente nelle Settings.
class CircleClockWidget extends ConsumerStatefulWidget {
  const CircleClockWidget({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<CircleClockWidget> createState() => _CircleClockWidgetState();
}

class _CircleClockWidgetState extends ConsumerState<CircleClockWidget> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  static final DateFormat _timeFormat = DateFormat.Hm();
  static final DateFormat _dateFormat = DateFormat('EEE, d MMM');

  @override
  void initState() {
    super.initState();
    // Il formato HH:mm cambia al massimo una volta al minuto: schedulare un
    // tick al secondo causa ~60 rebuild inutili al minuto solo per
    // refreshare un widget statico. Schedula invece al prossimo confine
    // di minuto, e si ri-schedula da solo dopo ogni tick.
    _scheduleTick();
  }

  void _scheduleTick() {
    _now = DateTime.now();
    final next = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _now.hour,
      _now.minute + 1,
    );
    _clockTimer = Timer(next.difference(_now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batteryLevel = ref.watch(batteryLevelProvider).valueOrNull;
    final isCharging = ref.watch(isChargingProvider).valueOrNull ?? false;
    final foreground =
        theme.textTheme.bodyMedium?.color ?? KoruColors.textPrimary;

    final timeString = _timeFormat.format(_now);
    final dateString = _dateFormat.format(_now);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                timeString,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                  color: foreground,
                  fontSize: 72,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateString,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground.withAlpha(180),
                letterSpacing: 1,
              ),
            ),
            if (batteryLevel != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCharging
                        ? Icons.bolt
                        : _batteryIconFor(batteryLevel),
                    size: 14,
                    color: foreground.withAlpha(140),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$batteryLevel%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground.withAlpha(140),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _batteryIconFor(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 70) return Icons.battery_6_bar;
    if (level >= 50) return Icons.battery_4_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level >= 15) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }
}
