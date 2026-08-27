import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_limits_provider.dart';
import '../../../providers/app_list_provider.dart';

/// Card riepilogo delle app con un daily limit attivo: mostra progress bar
/// usato/cap per ogni app.
///
/// Senza limiti impostati la card NON sparisce: mostra un invito a crearne uno.
/// Nasconderla lasciava la feature invisibile proprio a chi non l'ha ancora
/// scoperta — i limiti stanno sepolti in Impostazioni, e chi non sa che
/// esistono non va a cercarli. Il posto fisso in dashboard è anche l'unico
/// punto in cui l'app può proporli nel momento giusto.
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
    if (limits.isEmpty) return const _NoLimitsCard();

    // Fonte autoritativa per "questo pkg è ancora installato?":
    // [installedPackageNamesProvider] è cheap (~50ms, no icon decode)
    // quindi è disponibile entro un frame anche al cold start. La lista
    // ricca [installedAppsProvider] serve solo per i label (e arriva
    // 1-3s più tardi: fino ad allora fallback su `packageName` raw).
    //
    // Senza questo split, la card mostrava per ~3s tutte le entries del
    // JSON `koru_app_limits.json` — incluse quelle di app disinstallate
    // mentre Koru era in background e che non sono ancora state ripulite
    // dal cleanup async — perché il filtro era gated sulla lista ricca.
    final pkgNamesAsync = ref.watch(installedPackageNamesProvider);
    final appsAsync = ref.watch(installedAppsProvider);
    final installedNames = pkgNamesAsync.valueOrNull;
    final appsByPkg = {
      for (final a in appsAsync.valueOrNull ?? const <InstalledAppInfo>[])
        a.packageName: a,
    };

    // Se la lista cheap non e' ancora caricata (primissimo frame del cold
    // start, errore native, dispositivo senza app visibili) NON filtriamo
    // — meglio mostrare entries reali in eccesso che nascondere entries
    // valide per qualche millisecondo. In steady-state e' sempre caricata,
    // quindi non c'e' regressione visibile rispetto a prima.
    final filterActive = installedNames != null && installedNames.isNotEmpty;
    final entries = limits.entries
        .where((e) => !filterActive || installedNames.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.minutes.compareTo(a.value.minutes));
    // Tutti i limiti puntano ad app disinstallate (il cleanup async non è
    // ancora passato): per l'utente equivale a non averne, quindi stesso
    // invito invece di un buco.
    if (entries.isEmpty) return const _NoLimitsCard();

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
                  AppLocalizations.of(context).todayLimitsHeader.toUpperCase(),
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
                  child: Text(AppLocalizations.of(context).commonEdit),
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

/// Stato vuoto: nessun limite impostato (o nessuno che punti a un'app ancora
/// installata). Stessa scocca della card piena — header identico, corpo che
/// spiega cosa fa la feature e un solo tap per andarla a configurare.
///
/// L'intera card è tappabile *oltre* al bottone: il bersaglio grande è per chi
/// sta scoprendo la feature, il bottone è per chi sa già cosa vuole.
class _NoLimitsCard extends StatelessWidget {
  const _NoLimitsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/settings/app-limits'),
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
                    AppLocalizations.of(context).todayLimitsHeader
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: KoruColors.textSecondary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).todayLimitsEmptyTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: KoruColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).todayLimitsEmptyBody,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: KoruColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/settings/app-limits'),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppLocalizations.of(context).todayLimitsSetOne),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
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
                AppLocalizations.of(
                  context,
                ).todayLimitsUsedOfCap(used, limitMinutes),
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
