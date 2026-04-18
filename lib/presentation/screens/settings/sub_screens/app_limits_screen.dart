import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../providers/app_limits_provider.dart';
import '../../../providers/app_list_provider.dart';

/// Imposta un limite giornaliero (minuti/giorno) per app specifiche.
/// Quando l'utilizzo in foreground supera il limite, Koru mostra l'overlay
/// "Daily limit reached" e riporta alla home.
///
/// Le app con un limite attivo sono mostrate in cima (con badge minuti).
/// Tap su un'app → dialog per impostare/modificare i minuti.
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

  Future<void> _editLimit(String pkg, String label, int currentMinutes) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => _LimitPickerDialog(
        label: label,
        initialMinutes: currentMinutes,
      ),
    );
    if (chosen == null) return;
    await ref.read(appLimitsProvider.notifier).setLimit(pkg, chosen);
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
                prefixIcon: const Icon(Icons.search,
                    color: KoruColors.textSecondary),
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
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (apps) {
          final limits = limitsAsync.valueOrNull ?? const <String, int>{};
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? apps
              : apps
                  .where((a) =>
                      a.label.toLowerCase().contains(q) ||
                      a.packageName.toLowerCase().contains(q))
                  .toList(growable: false);
          // Sort: apps con limite in cima.
          final sorted = [...filtered]..sort((a, b) {
              final al = limits[a.packageName] ?? 0;
              final bl = limits[b.packageName] ?? 0;
              if ((al > 0) == (bl > 0)) return 0;
              return al > 0 ? -1 : 1;
            });
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
            itemCount: sorted.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    'Tap an app to set a daily minutes cap. When you reach '
                    'it, the app is blocked until tomorrow.',
                    style: TextStyle(
                      color: KoruColors.textSecondary,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              final app = sorted[i - 1];
              final minutes = limits[app.packageName] ?? 0;
              return _AppLimitRow(
                iconBytes: app.iconBytes,
                label: app.label,
                packageName: app.packageName,
                limitMinutes: minutes,
                onTap: () => _editLimit(app.packageName, app.label, minutes),
              );
            },
          );
        },
      ),
    );
  }
}

/// Row con icon + label + (se limite attivo) barra di progresso usato/cap.
class _AppLimitRow extends ConsumerWidget {
  const _AppLimitRow({
    required this.iconBytes,
    required this.label,
    required this.packageName,
    required this.limitMinutes,
    required this.onTap,
  });

  final dynamic iconBytes;
  final String label;
  final String packageName;
  final int limitMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLimit = limitMinutes > 0;
    final usedMinAsync = hasLimit
        ? ref.watch(usageTodayMinutesProvider(packageName))
        : null;
    final usedMin = usedMinAsync?.valueOrNull ?? 0;
    final progress = hasLimit
        ? (usedMin / limitMinutes).clamp(0.0, 1.0)
        : 0.0;
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
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15)),
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
                      '$usedMin / $limitMinutes min today',
                      style: TextStyle(
                        fontSize: 11,
                        color: exceeded
                            ? KoruColors.danger
                            : KoruColors.textSecondary,
                        fontWeight:
                            exceeded ? FontWeight.w600 : FontWeight.w400,
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
                        horizontal: 10, vertical: 4),
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
                : const Icon(Icons.chevron_right,
                    color: KoruColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _LimitPickerDialog extends StatefulWidget {
  const _LimitPickerDialog({
    required this.label,
    required this.initialMinutes,
  });

  final String label;
  final int initialMinutes;

  @override
  State<_LimitPickerDialog> createState() => _LimitPickerDialogState();
}

class _LimitPickerDialogState extends State<_LimitPickerDialog> {
  late double _minutes;
  static const _max = 360.0; // 6h
  static const _presets = <int>[15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    _minutes =
        (widget.initialMinutes == 0 ? 30 : widget.initialMinutes).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final value = _minutes.round();
    return AlertDialog(
      title: Text(widget.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value min/day',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
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
        ],
      ),
      actions: [
        if (widget.initialMinutes > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('Remove limit'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(value),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
