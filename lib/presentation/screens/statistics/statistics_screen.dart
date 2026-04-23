import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../domain/entities/statistics_period.dart';
import '../../../platform/blocking_channel.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/screen_time_provider.dart';
import '../../providers/statistics_providers.dart';
import '../mood/mood_check_in_sheet.dart';
import 'widgets/achievements_grid.dart';
import 'widgets/streaks_row.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(periodUsageProvider);
          ref.invalidate(blockTriggeredCountProvider);
          ref.invalidate(blockSkippedCountProvider);
          ref.invalidate(perAppBreakdownProvider);
          ref.invalidate(topIntentionsProvider);
          ref.invalidate(focusTimeMsProvider);
          ref.invalidate(todayMoodProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
          children: const [
            _PeriodSwitcher(),
            SizedBox(height: 16),
            _ScreenTimeCard(),
            SizedBox(height: 16),
            _TopAppsCard(),
            SizedBox(height: 16),
            _InterventionsCard(),
            SizedBox(height: 16),
            StreaksRow(),
            SizedBox(height: 16),
            AchievementsGrid(),
            SizedBox(height: 16),
            _MoodJournalCard(),
          ],
        ),
      ),
    );
  }
}

// ─── Period switcher (Today / Week / Month) ─────────────────────────────────

class _PeriodSwitcher extends ConsumerWidget {
  const _PeriodSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final p in StatisticsPeriod.values)
            Expanded(
              child: _PeriodPill(
                label: p.label,
                selected: p == period,
                onTap: () =>
                    ref.read(selectedPeriodProvider.notifier).state = p,
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KoruColors.surfaceElevated : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? KoruColors.textPrimary
                  : KoruColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Screen time card ───────────────────────────────────────────────────────

class _ScreenTimeCard extends ConsumerWidget {
  const _ScreenTimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowAsync = ref.watch(periodScreenTimeMsProvider);
    final prevAsync = ref.watch(previousPeriodScreenTimeMsProvider);
    final period = ref.watch(selectedPeriodProvider);
    final now = nowAsync.valueOrNull ?? 0;
    final prev = prevAsync.valueOrNull ?? 0;

    return _Card(
      child: Column(
        children: [
          const _SectionLabel('Screen time', center: true),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatMs(now),
              style: const TextStyle(
                color: KoruColors.textPrimary,
                fontSize: 56,
                fontWeight: FontWeight.w300,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DeltaText(current: now, previous: prev, period: period),
        ],
      ),
    );
  }

  static String _formatMs(int ms) {
    final totalMinutes = (ms / 60000).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _DeltaText extends StatelessWidget {
  const _DeltaText({
    required this.current,
    required this.previous,
    required this.period,
  });
  final int current;
  final int previous;
  final StatisticsPeriod period;

  String _periodRef() => switch (period) {
        StatisticsPeriod.today => 'yesterday',
        StatisticsPeriod.week => 'last week',
        StatisticsPeriod.month => 'last month',
      };

  @override
  Widget build(BuildContext context) {
    if (previous == 0) {
      return Text(
        'no data from ${_periodRef()}',
        style: const TextStyle(
          color: KoruColors.textSecondary,
          fontSize: 13,
        ),
      );
    }
    final diff = current - previous;
    final pct = (diff / previous * 100).round();
    final increased = pct > 0;
    final color = increased ? KoruColors.danger : KoruColors.success;
    final sign = increased ? '+' : '';
    return Text(
      '$sign$pct% from ${_periodRef()}',
      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
    );
  }
}

// ─── Top apps card ──────────────────────────────────────────────────────────

class _TopAppsCard extends ConsumerWidget {
  const _TopAppsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topAsync = ref.watch(topAppsByUsageProvider(5));
    final appsAsync = ref.watch(installedAppsProvider);
    final top = topAsync.valueOrNull ?? const <AppUsageInfo>[];
    final labels = <String, String>{
      for (final a in appsAsync.valueOrNull ?? const <InstalledAppInfo>[])
        a.packageName: a.label,
    };

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Top apps'),
          const SizedBox(height: 14),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No foreground usage recorded for this period.',
                style: TextStyle(color: KoruColors.textSecondary, fontSize: 13),
              ),
            )
          else
            _TopAppsList(top: top, labels: labels),
        ],
      ),
    );
  }
}

class _TopAppsList extends StatelessWidget {
  const _TopAppsList({required this.top, required this.labels});
  final List<AppUsageInfo> top;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final maxMs = top.isEmpty ? 1 : top.first.totalTimeMs;
    return Column(
      children: [
        for (var i = 0; i < top.length; i++) ...[
          _AppUsageRow(
            label: labels[top[i].packageName] ?? top[i].packageName,
            ms: top[i].totalTimeMs,
            fraction: maxMs == 0 ? 0 : top[i].totalTimeMs / maxMs,
          ),
          if (i < top.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.label,
    required this.ms,
    required this.fraction,
  });
  final String label;
  final int ms;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KoruColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _formatMs(ms),
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1).toDouble(),
            minHeight: 5,
            backgroundColor: KoruColors.surfaceElevated,
            valueColor:
                const AlwaysStoppedAnimation<Color>(KoruColors.primary),
          ),
        ),
      ],
    );
  }

  static String _formatMs(int ms) {
    final totalMinutes = (ms / 60000).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ─── Interventions card (donut + legend) ────────────────────────────────────

class _InterventionsCard extends ConsumerWidget {
  const _InterventionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggered = ref.watch(blockTriggeredCountProvider).valueOrNull ?? 0;
    final skipped = ref.watch(blockSkippedCountProvider).valueOrNull ?? 0;
    final respected = (triggered - skipped).clamp(0, 1 << 30);
    final total = respected + skipped;

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _DonutPainter(
                total: total,
                respected: respected,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Interventions'),
                const SizedBox(height: 12),
                _LegendRow(
                  color: KoruColors.success,
                  label: total == 0
                      ? 'No blocks yet'
                      : '${(respected * 100 / total).round()}% respected',
                ),
                const SizedBox(height: 6),
                _LegendRow(
                  color: KoruColors.danger,
                  label: total == 0
                      ? '—'
                      : '${(skipped * 100 / total).round()}% skipped',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: KoruColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.total, required this.respected});
  final int total;
  final int respected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;
    final strokeWidth = 10.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = KoruColors.surfaceElevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, bgPaint);

    if (total == 0) return;

    final respFraction = respected / total;
    final skipFraction = 1 - respFraction;
    final gap = 0.06; // small gap between arcs, radians

    final respPaint = Paint()
      ..color = KoruColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final skipPaint = Paint()
      ..color = KoruColors.danger
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fullSweep = 2 * math.pi;
    final start = -math.pi / 2;
    final respSweep = respFraction * fullSweep - gap;
    if (respSweep > 0) {
      canvas.drawArc(rect, start + gap / 2, respSweep, false, respPaint);
    }
    final skipStart = start + respFraction * fullSweep + gap / 2;
    final skipSweep = skipFraction * fullSweep - gap;
    if (skipSweep > 0) {
      canvas.drawArc(rect, skipStart, skipSweep, false, skipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.respected != respected;
}

// ─── Mood + Journal quick access card ───────────────────────────────────────

class _MoodJournalCard extends ConsumerWidget {
  const _MoodJournalCard();

  String _emojiFor(int mood) => switch (mood) {
        1 => '😫',
        2 => '😔',
        3 => '😐',
        4 => '🙂',
        _ => '😊',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayMood = ref.watch(todayMoodProvider).valueOrNull;
    final has = todayMood != null;
    return _Card(
      child: Row(
        children: [
          Text(
            has ? _emojiFor(todayMood.mood) : '🌱',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  has ? 'You checked in today' : 'How do you feel?',
                  style: const TextStyle(
                    color: KoruColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  has
                      ? (todayMood.note ?? 'Tap to update')
                      : 'Pause for 10 seconds and notice.',
                  style: const TextStyle(
                    color: KoruColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: KoruColors.primary,
            ),
            onPressed: () => MoodCheckInSheet.show(context),
            child: Text(has ? 'Update' : 'Check in'),
          ),
          IconButton(
            tooltip: 'Journal',
            icon: const Icon(Icons.edit_note_outlined,
                color: KoruColors.textSecondary),
            onPressed: () => context.push('/stats/journal'),
          ),
        ],
      ),
    );
  }
}

// ─── Shared primitives ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: KoruColors.primary.withAlpha(220),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
