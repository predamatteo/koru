import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/koru_type.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../providers/battery_provider.dart';
import '../../../widgets/minute_tick_builder.dart';

/// Le **ore**, metà del nome del launcher.
///
/// Serif editoriale allineato a sinistra, non digitale centrato: è il primo
/// segno che questo non è un launcher come gli altri. Sotto, una sola riga
/// mono di meta — data, batteria, fascia — al posto della vecchia colonna
/// data + icona batteria + percentuale.
///
/// L'ora è formattata `HH:mm`: cambia al massimo una volta al minuto, ed è
/// esattamente quanto spesso questo widget si ridisegna (vedi
/// [MinuteTickBuilder]).
class CircleClockWidget extends ConsumerWidget {
  const CircleClockWidget({required this.phase, super.key, this.onTap});

  final LauncherPhase phase;
  final VoidCallback? onTap;

  static final DateFormat _timeFormat = DateFormat.Hm();
  static final DateFormat _dateFormat = DateFormat('EEE d MMM');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryLevel = ref.watch(batteryLevelProvider).valueOrNull;
    final isCharging = ref.watch(isChargingProvider).valueOrNull ?? false;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MinuteTickBuilder(
        builder: (context, now) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Il 104px è la misura di riferimento; FittedBox la riduce solo
            // se il formato locale è più largo (es. `10:44 PM` a 12 ore).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _timeFormat.format(now),
                maxLines: 1,
                style: KoruType.serif(
                  size: 104,
                  height: 0.84,
                  letterSpacingEm: -0.03,
                  color: phase.ink,
                  opacity: phase.clockOpacity,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _metaLine(now, batteryLevel, isCharging),
              style: KoruType.mono(
                size: 10,
                color: phase.ink2,
                trackEm: phase.trackEm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `MON 9 JUN · 76% CHARGING · NIGHT` — una riga sola, segmenti separati da
  /// `·`. Il segmento batteria sparisce se il livello non è ancora noto,
  /// invece di lasciare un buco o uno `0%` finto.
  String _metaLine(DateTime now, int? batteryLevel, bool isCharging) {
    final parts = <String>[_dateFormat.format(now).toUpperCase()];
    if (batteryLevel != null && batteryLevel >= 0) {
      // Nessuna icona: il dogma solo-testo del launcher vale anche qui, dove
      // prima c'erano `Icons.bolt` / `Icons.battery_*`.
      parts.add(isCharging ? '$batteryLevel% CHARGING' : '$batteryLevel%');
    }
    parts.add(phase.label);
    return parts.join(' · ');
  }
}
