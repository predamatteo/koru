import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_limits_provider.dart';
import '../../../providers/app_list_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

/// Imposta un limite giornaliero (minuti/giorno) per app specifiche, con
/// flag opzionale "Strict" che impedisce il bypass una volta raggiunto il
/// cap. Quando Strict è OFF, l'utente può bypassare ma con frizione
/// progressiva (countdown crescente, durate decrescenti).
///
/// Le app con un limite attivo sono mostrate in cima (con badge minuti).
/// Tap su un'app → dialog per impostare/modificare i minuti e lo strict.
class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editLimit(
    String pkg,
    String label,
    AppLimitConfig? current,
  ) async {
    final chosen = await showDialog<AppLimitConfig?>(
      context: context,
      builder: (ctx) => _LimitPickerDialog(label: label, initial: current),
    );
    if (chosen == null) return;
    // `chosen.minutes == 0` è il sentinel "remove limit" emesso dal dialog.
    if (chosen.minutes <= 0) {
      await ref.read(appLimitsProvider.notifier).clear(pkg);
    } else {
      await ref
          .read(appLimitsProvider.notifier)
          .setLimit(pkg, chosen.minutes, strict: chosen.strict);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitsAsync = ref.watch(appLimitsProvider);
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App daily limits'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search apps',
                prefixIcon: const Icon(
                  Icons.search,
                  color: KoruColors.textSecondary,
                ),
                filled: true,
                fillColor: KoruColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: KoruPullToRefresh(
        child: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (apps) {
            final limits =
                limitsAsync.valueOrNull ?? const <String, AppLimitConfig>{};
            final q = _query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? apps
                : apps
                      .where(
                        (a) =>
                            a.label.toLowerCase().contains(q) ||
                            a.packageName.toLowerCase().contains(q),
                      )
                      .toList(growable: false);
            // Sort: apps con limite in cima.
            final sorted = [...filtered]
              ..sort((a, b) {
                final al = limits[a.packageName]?.minutes ?? 0;
                final bl = limits[b.packageName]?.minutes ?? 0;
                if ((al > 0) == (bl > 0)) return 0;
                return al > 0 ? -1 : 1;
              });
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
              itemCount: sorted.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'Tap an app to set a daily minutes cap. Strict mode '
                      'enforces a hard cap (no bypass). Otherwise, bypassing '
                      'is allowed but gets harder each time.',
                      style: TextStyle(
                        color: KoruColors.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final app = sorted[i - 1];
                final cfg = limits[app.packageName];
                return _AppLimitRow(
                  iconBytes: app.iconBytes,
                  label: app.label,
                  packageName: app.packageName,
                  limit: cfg,
                  onTap: () => _editLimit(app.packageName, app.label, cfg),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Row con icon + label + (se limite attivo) barra di progresso usato/cap
/// + badge minuti + (eventuale) icona lock se strict.
class _AppLimitRow extends ConsumerWidget {
  const _AppLimitRow({
    required this.iconBytes,
    required this.label,
    required this.packageName,
    required this.limit,
    required this.onTap,
  });

  final dynamic iconBytes;
  final String label;
  final String packageName;
  final AppLimitConfig? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLimit = limit != null && limit!.minutes > 0;
    final limitMinutes = limit?.minutes ?? 0;
    final isStrict = limit?.strict ?? false;
    final usedMinAsync = hasLimit
        ? ref.watch(usageTodayMinutesProvider(packageName))
        : null;
    final usedMin = usedMinAsync?.valueOrNull ?? 0;
    final progress = hasLimit ? (usedMin / limitMinutes).clamp(0.0, 1.0) : 0.0;
    final exceeded = hasLimit && usedMin >= limitMinutes;
    final barColor = exceeded
        ? KoruColors.danger
        : (progress > 0.8 ? KoruColors.secondary : KoruColors.primary);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            iconBytes != null
                ? Image.memory(iconBytes, width: 40, height: 40)
                : const SizedBox(width: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      if (hasLimit && isStrict) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: KoruColors.primary,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (hasLimit) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: KoruColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$usedMin / $limitMinutes min today'
                      '${isStrict ? ' · strict' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: exceeded
                            ? KoruColors.danger
                            : KoruColors.textSecondary,
                        fontWeight: exceeded
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            hasLimit
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: KoruColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$limitMinutes m',
                      style: const TextStyle(
                        color: KoruColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.chevron_right,
                    color: KoruColors.textSecondary,
                  ),
          ],
        ),
      ),
    );
  }
}

/// Dialog per impostare minuti + strict flag. Default: minuti=30 (o
/// l'esistente), strict=true (hard cap fin dal primo set).
class _LimitPickerDialog extends StatefulWidget {
  const _LimitPickerDialog({required this.label, required this.initial});

  final String label;
  final AppLimitConfig? initial;

  @override
  State<_LimitPickerDialog> createState() => _LimitPickerDialogState();
}

class _LimitPickerDialogState extends State<_LimitPickerDialog> {
  late double _minutes;
  late bool _strict;
  static const _max = 360.0; // 6h
  static const _presets = <int>[15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _minutes = (initial?.minutes ?? 30).clamp(5, _max.toInt()).toDouble();
    // Default per nuovi limiti: strict ON. Per esistenti: rispetta il valore
    // salvato (anche se è una migrazione dal formato legacy, lo store ritorna
    // strict=true di default).
    _strict = initial?.strict ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final value = _minutes.round();
    return AlertDialog(
      title: Text(widget.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value min/day',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _minutes,
              min: 5,
              max: _max,
              divisions: ((_max - 5) / 5).round(),
              label: '$value',
              onChanged: (v) => setState(() => _minutes = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text('${p}m'),
                    selected: value == p,
                    onSelected: (_) => setState(() => _minutes = p.toDouble()),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Toggle Strict mode: quando ON, raggiunto il cap non c'è
            // "Open anyway". Quando OFF, l'utente può bypassare ma con
            // friction crescente (countdown 15→30→60→120s, durate 5/10
            // → 1/2 min dopo 3 bypass).
            Container(
              decoration: BoxDecoration(
                color: KoruColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Strict daily limit',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  _strict
                      ? 'Hard cap. No "Open anyway" once reached.'
                      : 'Bypass allowed, gets harder each time today.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: KoruColors.textSecondary,
                  ),
                ),
                value: _strict,
                onChanged: (v) => setState(() => _strict = v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if ((widget.initial?.minutes ?? 0) > 0)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const AppLimitConfig(minutes: 0, strict: true)),
            child: const Text('Remove limit'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(AppLimitConfig(minutes: value, strict: _strict)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
