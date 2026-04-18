import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../providers/app_limits_provider.dart';
import '../../../providers/app_list_provider.dart';

/// Card riepilogo delle app con un daily limit attivo: mostra
/// progress bar usato/cap per ogni app. Visibile solo se almeno un
/// limite è impostato.
class TodayLimitsCard extends ConsumerWidget {
  const TodayLimitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitsAsync = ref.watch(appLimitsProvider);
    final limits = limitsAsync.valueOrNull ?? const <String, int>{};
    if (limits.isEmpty) return const SizedBox.shrink();

    final appsAsync = ref.watch(installedAppsProvider);
    final appsByPkg = {
      for (final a in appsAsync.valueOrNull ?? const []) a.packageName: a,
    };

    final entries = limits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_bottom_outlined,
                    size: 18, color: KoruColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  "TODAY'S LIMITS",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KoruColors.textSecondary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.push('/settings/app-limits'),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in entries)
              _LimitRow(
                label: appsByPkg[e.key]?.label ?? e.key,
                packageName: e.key,
                limitMinutes: e.value,
              ),
          ],
        ),
      ),
    );
  }
}

class _LimitRow extends ConsumerWidget {
  const _LimitRow({
    required this.label,
    required this.packageName,
    required this.limitMinutes,
  });

  final String label;
  final String packageName;
  final int limitMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usedAsync = ref.watch(usageTodayMinutesProvider(packageName));
    final used = usedAsync.valueOrNull ?? 0;
    final progress = (used / limitMinutes).clamp(0.0, 1.0);
    final exceeded = used >= limitMinutes;
    final barColor = exceeded
        ? KoruColors.danger
        : (progress > 0.8 ? KoruColors.secondary : KoruColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '$used / $limitMinutes min',
                style: TextStyle(
                  fontSize: 12,
                  color: exceeded
                      ? KoruColors.danger
                      : KoruColors.textSecondary,
                  fontWeight:
                      exceeded ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: KoruColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
