import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../providers/battery_provider.dart';
import '../../../widgets/minute_tick_builder.dart';

/// Orologio del launcher: ora grande allineata a sinistra, sotto una sola riga
/// di meta (data, batteria).
///
/// **Tipografia**: `displayLarge` della type scale Material 3, ingrandita per
/// la scala da launcher. Nessuna famiglia hardcoded — segue il font scelto in
/// Impostazioni → Font come il resto dell'app (prima era Orbitron fisso).
///
/// L'ora è formattata `HH:mm`: cambia al massimo una volta al minuto, ed è
/// esattamente quanto spesso questo widget si ridisegna (vedi
/// [MinuteTickBuilder]).
class CircleClockWidget extends ConsumerWidget {
  const CircleClockWidget({required this.phase, super.key, this.onTap});

  final LauncherPhase phase;
  final VoidCallback? onTap;

  // I formatter si costruiscono nel build e non sono `static final`: un
  // `DateFormat` cattura il locale al momento della creazione, quindi uno
  // statico resterebbe congelato sulla lingua del primo avvio e la data
  // continuerebbe a dire "Wed" con la UI in italiano. I simboli della lingua
  // sono già caricati da `GlobalMaterialLocalizations` (vedi
  // `AppLocalizations.localizationsDelegates`).

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final timeFormat = DateFormat.Hm(localeTag);
    final dateFormat = DateFormat('EEE d MMM', localeTag);
    final batteryLevel = ref.watch(batteryLevelProvider).valueOrNull;
    final isCharging = ref.watch(isChargingProvider).valueOrNull ?? false;
    final metaStyle = theme.textTheme.labelLarge?.copyWith(
      color: KoruColors.textSecondary,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MinuteTickBuilder(
        builder: (context, now) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 76 è la misura di riferimento; FittedBox la riduce solo se il
            // formato locale è più largo (es. `10:44 PM` a 12 ore).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                timeFormat.format(now),
                maxLines: 1,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 76,
                  height: 1.05,
                  letterSpacing: -1.5,
                  color: KoruColors.textPrimary
                      .withValues(alpha: phase.clockOpacity),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dateFormat.format(now), style: metaStyle),
                if (batteryLevel != null && batteryLevel >= 0) ...[
                  Text(' · ', style: metaStyle),
                  if (isCharging) ...[
                    Icon(
                      Icons.bolt,
                      size: 15,
                      color: KoruColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                  ],
                  Text('$batteryLevel%', style: metaStyle),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
