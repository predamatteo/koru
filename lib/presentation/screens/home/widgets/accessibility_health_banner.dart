import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../providers/accessibility_health_provider.dart';

/// Banner che appare in cima alla home quando il servizio di accessibilità
/// di Koru NON è attivo nel sistema. È la situazione in cui *nessun blocco
/// funziona* (limiti giornalieri, profili, focus, website blocking) — gli
/// OEM aggressivi sui processi (OPPO/ColorOS, MIUI, Samsung) capita che
/// disabilitino il servizio dopo ripetuti kill, senza avvertire l'utente.
///
/// Il provider [accessibilityHealthProvider] fa polling ogni 5s e ricontrola
/// anche al ritorno in foreground. Quando lo stato passa a `false` il banner
/// compare immediatamente con un CTA che apre direttamente le Settings di
/// accessibilità di sistema (Settings.ACTION_ACCESSIBILITY_SETTINGS).
class AccessibilityHealthBanner extends ConsumerWidget {
  const AccessibilityHealthBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOk = ref.watch(accessibilityHealthProvider);
    // Mentre il primo check è in volo (loading) NON mostriamo nulla:
    // evita un flash del banner all'apertura della home se l'utente
    // ha tutto a posto.
    final isHealthy = asyncOk.valueOrNull ?? true;
    if (isHealthy) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: KoruColors.dangerContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openSettings(ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: KoruColors.danger,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Koru blocking is OFF',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: KoruColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Accessibility service was disabled by the system. '
                        'Limits, profiles and focus mode will not work until '
                        'you re-enable it.',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: KoruColors.textSecondary,
                                  height: 1.35,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: KoruColors.danger,
                            foregroundColor: KoruColors.onDanger,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _openSettings(ref),
                          child: const Text('Re-enable'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings(WidgetRef ref) async {
    await ref
        .read(platformChannelServiceProvider)
        .permission
        .openAccessibilitySettings();
  }
}
