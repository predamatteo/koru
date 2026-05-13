import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_limits_provider.dart';
import '../../../providers/app_list_provider.dart';

/// Card riepilogo delle app con un daily limit attivo: mostra
/// progress bar usato/cap per ogni app. Visibile solo se almeno un
/// limite è impostato.
class TodayLimitsCard extends ConsumerStatefulWidget {
  const TodayLimitsCard({super.key});

  @override
  ConsumerState<TodayLimitsCard> createState() => _TodayLimitsCardState();
}

class _TodayLimitsCardState extends ConsumerState<TodayLimitsCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Polling 15s del usage minutes per ogni limite visibile. Bug riportato:
    // senza questo ticker, i progress bar restavano fermi finche' l'utente
    // non chiudeva e riapriva Koru. Tenere il polling QUI invece che dentro
    // [usageTodayMinutesProvider] evita di trasformare quel provider in
    // StreamProvider (cambierebbe l'API e farebbe time-out i test esistenti
    // che fanno `read(...future)`).
    //
    // Trade-off 15s: bilancia freschezza percepita con budget chiamate
    // native (`getUsageTodayMs` legge UsageStats, ~few ms ognuna). Per
    // 5 app con limite attivo = 20 query/min, trascurabile.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final limits = ref.read(appLimitsProvider).valueOrNull;
      if (limits == null) return;
      for (final pkg in limits.keys) {
        ref.invalidate(usageTodayMinutesProvider(pkg));
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limitsAsync = ref.watch(appLimitsProvider);
    final limits = limitsAsync.valueOrNull ?? const <String, AppLimitConfig>{};
    if (limits.isEmpty) return const SizedBox.shrink();

    final appsAsync = ref.watch(installedAppsProvider);
    final apps = appsAsync.valueOrNull;
    final appsByPkg = {
      for (final a in apps ?? const []) a.packageName: a,
    };

    // Filtra entries per package non piu' installati. Bug riportato: dopo
    // disinstallazione di un'app con limite il JSON `koru_app_limits.json`
    // conservava la entry, facendola riapparire come voce fantasma sotto
    // "Today's limits". Il cleanup persistente avviene via
    // [packageEventsRefresherProvider] (su PACKAGE_REMOVED) e via
    // [appLifecycleInvalidatorProvider] (sweep al resume); qui filtriamo
    // anche per coprire la finestra fra il momento in cui la entry diventa
    // stale e il momento in cui il cleanup arriva al disco.
    //
    // Se la lista installedApps non e' ancora caricata (apps == null) o
    // ritorna vuota (errore native, cold start, dispositivo senza app
    // visibili), mostriamo tutto: meglio mostrare entries reali in
    // eccesso che nascondere temporaneamente entries valide. Il filtro
    // serve a coprire il caso steady-state in cui c'e' una lista reale
    // di app installate e il pkg del limit non vi compare (uninstall
    // gia' avvenuto, cleanup non ancora persistito).
    final filterActive = apps != null && apps.isNotEmpty;
    final entries = limits.entries
        .where((e) => !filterActive || appsByPkg.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.minutes.compareTo(a.value.minutes));
    if (entries.isEmpty) return const SizedBox.shrink();

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
                limitMinutes: e.value.minutes,
                strict: e.value.strict,
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
    required this.strict,
  });

  final String label;
  final String packageName;
  final int limitMinutes;
  final bool strict;

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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (strict) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: KoruColors.textSecondary,
                      ),
                    ],
                  ],
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
