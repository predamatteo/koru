import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../domain/entities/statistics_period.dart';
import '../../providers/mood_provider.dart';
import '../../providers/statistics_providers.dart';
import '../mood/mood_check_in_sheet.dart';
import 'widgets/achievements_grid.dart';
import 'widgets/streaks_row.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final triggered = ref.watch(blockTriggeredCountProvider).valueOrNull ?? 0;
    final skipped = ref.watch(blockSkippedCountProvider).valueOrNull ?? 0;
    final perApp = ref.watch(perAppBreakdownProvider).valueOrNull ?? const [];
    final intentions = ref.watch(topIntentionsProvider).valueOrNull ?? const [];
    final focusMs = ref.watch(focusTimeMsProvider).valueOrNull ?? 0;
    final todayMood = ref.watch(todayMoodProvider).valueOrNull;

    final topApps = perApp.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(blockTriggeredCountProvider);
          ref.invalidate(blockSkippedCountProvider);
          ref.invalidate(perAppBreakdownProvider);
          ref.invalidate(topIntentionsProvider);
          ref.invalidate(focusTimeMsProvider);
          ref.invalidate(todayMoodProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavClearance),
          children: [
            const StreaksRow(),
            const SizedBox(height: 16),
            SegmentedButton<StatisticsPeriod>(
              segments: [
                for (final p in StatisticsPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(selectedPeriodProvider.notifier).state = s.first,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Blocks',
                    value: '$triggered',
                    icon: Icons.shield_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Skipped',
                    value: '$skipped',
                    icon: Icons.fast_forward_outlined,
                    valueColor: KoruColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Focus',
                    value: _formatMs(focusMs),
                    icon: Icons.self_improvement,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AchievementsGrid(),
            const SizedBox(height: 16),
            _MoodCard(todayMood: todayMood),
            const SizedBox(height: 16),
            if (topApps.isNotEmpty) ...[
              Text(
                'Top blocked apps',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1.6,
                child: _TopAppsChart(stats: topApps),
              ),
            ],
            if (intentions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Top intentions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...intentions.take(5).map(
                    (i) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bookmark_outline,
                          color: KoruColors.secondary),
                      title: Text(i.title),
                      trailing: Text('${i.usageCount}',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KoruColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: KoruColors.textSecondary),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: valueColor ?? KoruColors.textPrimary,
                    )),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KoruColors.textSecondary,
                    )),
          ],
        ),
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.todayMood});

  final dynamic todayMood;

  @override
  Widget build(BuildContext context) {
    final has = todayMood != null;
    return Card(
      color: KoruColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              has ? _emojiFor(todayMood.mood as int) : '🌱',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(has ? 'You checked in today' : 'How do you feel today?',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    has
                        ? (todayMood.note as String?) ?? 'Tap to update'
                        : 'Pause for 10 seconds and notice.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KoruColors.textSecondary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => MoodCheckInSheet.show(context),
              child: Text(has ? 'Update' : 'Check in'),
            ),
          ],
        ),
      ),
    );
  }

  String _emojiFor(int mood) => switch (mood) {
        1 => '😫',
        2 => '😔',
        3 => '😐',
        4 => '🙂',
        _ => '😊',
      };
}

class _TopAppsChart extends StatelessWidget {
  const _TopAppsChart({required this.stats});

  final List<dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final maxY = stats
            .map((s) => s.count as int)
            .fold<int>(1, (m, v) => v > m ? v : m)
            .toDouble() *
        1.1;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < stats.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (stats[i].count as int).toDouble(),
                  color: KoruColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  width: 22,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                final pkg = stats[i].packageName as String;
                final short = pkg.split('.').last;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short.length > 8 ? '${short.substring(0, 7)}…' : short,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: KoruColors.textSecondary,
                        ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
