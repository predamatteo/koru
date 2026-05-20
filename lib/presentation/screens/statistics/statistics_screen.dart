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
import '../../widgets/koru_pull_to_refresh.dart';
import '../mood/mood_check_in_sheet.dart';
import 'widgets/achievements_grid.dart';
import 'widgets/streaks_row.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWeek = ref.watch(selectedPeriodProvider) == StatisticsPeriod.week;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
          children: [
            const _PeriodSwitcher(),
            const SizedBox(height: 16),
            const _ScreenTimeCard(),
            const SizedBox(height: 16),
            // Drill-down per-giorno: visibile solo nella vista settimana,
            // dove ha senso confrontare i singoli giorni.
            if (isWeek) ...const [
              _WeeklyUsageChart(),
              SizedBox(height: 16),
            ],
            const _TopAppsCard(),
            const SizedBox(height: 16),
            const _InterventionsCard(),
            const SizedBox(height: 16),
            const StreaksRow(),
            const SizedBox(height: 16),
            const AchievementsGrid(),
            const SizedBox(height: 16),
            const _MoodJournalCard(),
          ],
        ),
      ),
    );
  }
}

// ─── Period switcher (Today / Week) ─────────────────────────────────────────

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
                onTap: () {
                  ref.read(selectedPeriodProvider.notifier).state = p;
                  // Cambiare periodo azzera l'eventuale giorno selezionato:
                  // una selezione "appiccicata" sarebbe confondente.
                  ref.read(selectedStatsDayProvider.notifier).state = null;
                },
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
    final period = ref.watch(selectedPeriodProvider);
    // In vista settimana, se l'utente ha selezionato un giorno dal grafico,
    // la card mostra QUEL giorno invece dell'aggregato settimanale.
    final selDay = period == StatisticsPeriod.week
        ? ref.watch(selectedDayUsageProvider)
        : null;

    final int now;
    final Widget subtitle;
    if (selDay != null) {
      now = selDay.totalMs;
      subtitle = Text(
        _dayLabel(selDay.dayStartMs),
        style: const TextStyle(color: KoruColors.textSecondary, fontSize: 13),
      );
    } else {
      now = ref.watch(periodScreenTimeMsProvider).valueOrNull ?? 0;
      final prev =
          ref.watch(previousPeriodScreenTimeMsProvider).valueOrNull ?? 0;
      subtitle = _DeltaText(current: now, previous: prev, period: period);
    }

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
          subtitle,
        ],
      ),
    );
  }

  static String _formatMs(int ms) => _fmtDurationMs(ms);
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
  };

  @override
  Widget build(BuildContext context) {
    if (previous == 0) {
      return Text(
        'no data from ${_periodRef()}',
        style: const TextStyle(color: KoruColors.textSecondary, fontSize: 13),
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

// ─── Weekly per-day usage chart (week view only) ────────────────────────────

class _WeeklyUsageChart extends ConsumerWidget {
  const _WeeklyUsageChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weeklyDailyUsageProvider);
    final selected = ref.watch(selectedStatsDayProvider);
    final days = weekAsync.valueOrNull ?? const <DailyUsage>[];

    final selDay = _findDay(days, selected);
    final caption = selDay != null
        ? '${_dayLabel(selDay.dayStartMs)} · ${_fmtDurationMs(selDay.totalMs)}'
        : 'Tap a day to see its apps';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Daily breakdown')),
              if (selected != null)
                _ResetDayButton(
                  onTap: () =>
                      ref.read(selectedStatsDayProvider.notifier).state = null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: const TextStyle(
              color: KoruColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 112,
            child: days.isEmpty
                ? Center(
                    child: Text(
                      weekAsync.isLoading ? 'Loading…' : 'No usage recorded',
                      style: const TextStyle(
                        color: KoruColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : _DayBars(
                    days: days,
                    selectedMs: selected,
                    onTap: (ms) {
                      // Tap sul giorno già selezionato → torna all'aggregato.
                      final notifier =
                          ref.read(selectedStatsDayProvider.notifier);
                      notifier.state = selected == ms ? null : ms;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResetDayButton extends StatelessWidget {
  const _ResetDayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, size: 13, color: KoruColors.primary),
            SizedBox(width: 4),
            Text(
              'Whole week',
              style: TextStyle(
                color: KoruColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({
    required this.days,
    required this.selectedMs,
    required this.onTap,
  });
  final List<DailyUsage> days;
  final int? selectedMs;
  final ValueChanged<int> onTap;

  static const double _barAreaHeight = 80;
  static const double _minBarHeight = 6;
  static const double _barWidth = 12;

  @override
  Widget build(BuildContext context) {
    final maxMs = days.fold<int>(0, (m, d) => math.max(m, d.totalMs));
    final anySelected = selectedMs != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in days)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(d.dayStartMs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: _barAreaHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _bar(d, maxMs, anySelected),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _weekdayInitial(d.dayStartMs),
                    style: TextStyle(
                      color: _labelColor(d),
                      fontSize: 12,
                      fontWeight: _isSelected(d) || _isToday(d.dayStartMs)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _isSelected(DailyUsage d) => selectedMs == d.dayStartMs;

  Color _labelColor(DailyUsage d) {
    if (_isSelected(d)) return KoruColors.primary;
    if (_isToday(d.dayStartMs)) return KoruColors.textPrimary;
    return KoruColors.textSecondary;
  }

  Widget _bar(DailyUsage d, int maxMs, bool anySelected) {
    // Giorni senza utilizzo: tick di base, così la colonna resta visibile
    // e cliccabile.
    if (d.totalMs == 0) {
      return Container(
        width: _barWidth,
        height: 4,
        decoration: BoxDecoration(
          color: KoruColors.surfaceElevated,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final fraction = maxMs == 0 ? 0.0 : d.totalMs / maxMs;
    final height = math.max(_minBarHeight, fraction * _barAreaHeight);
    final Color color;
    if (_isSelected(d)) {
      color = KoruColors.primary;
    } else if (anySelected) {
      // Un giorno è selezionato: gli altri sono attenuati.
      color = KoruColors.primaryContainer;
    } else {
      color = KoruColors.primary.withAlpha(170);
    }
    return Container(
      width: _barWidth,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ─── Top apps card ──────────────────────────────────────────────────────────

class _TopAppsCard extends ConsumerWidget {
  const _TopAppsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final selDay = period == StatisticsPeriod.week
        ? ref.watch(selectedDayUsageProvider)
        : null;
    final appsAsync = ref.watch(installedAppsProvider);
    final labels = <String, String>{
      for (final a in appsAsync.valueOrNull ?? const <InstalledAppInfo>[])
        a.packageName: a.label,
    };

    final List<AppUsageInfo> top;
    if (selDay != null) {
      top = ([...selDay.apps]
            ..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs)))
          .take(5)
          .toList(growable: false);
    } else {
      top = ref.watch(topAppsByUsageProvider(5)).valueOrNull ??
          const <AppUsageInfo>[];
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Top apps'),
          if (selDay != null) ...[
            const SizedBox(height: 4),
            Text(
              _dayLabel(selDay.dayStartMs),
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                selDay != null
                    ? 'No usage recorded for this day.'
                    : 'No foreground usage recorded for this period.',
                style: const TextStyle(
                  color: KoruColors.textSecondary,
                  fontSize: 13,
                ),
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
              _fmtDurationMs(ms),
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
            valueColor: const AlwaysStoppedAnimation<Color>(KoruColors.primary),
          ),
        ),
      ],
    );
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
              painter: _DonutPainter(total: total, respected: respected),
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
            style: const TextStyle(color: KoruColors.textPrimary, fontSize: 14),
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
            icon: const Icon(
              Icons.edit_note_outlined,
              color: KoruColors.textSecondary,
            ),
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

// ─── Formatting helpers ─────────────────────────────────────────────────────

String _fmtDurationMs(int ms) {
  final totalMinutes = (ms / 60000).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _weekdayInitial(int dayStartMs) {
  final wd = DateTime.fromMillisecondsSinceEpoch(dayStartMs).weekday; // 1..7
  return _weekdayInitials[wd - 1];
}

bool _isToday(int dayStartMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(dayStartMs);
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

/// Etichetta amichevole per un giorno: "Today" / "Yesterday" o
/// "Wed 14 May". Il diff è arrotondato sulle ore per non sbagliare di un
/// giorno a cavallo dei cambi di ora legale.
String _dayLabel(int dayStartMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(dayStartMs);
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = (today.difference(that).inHours / 24).round();
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]}';
}

DailyUsage? _findDay(List<DailyUsage> days, int? ms) {
  if (ms == null) return null;
  for (final d in days) {
    if (d.dayStartMs == ms) return d;
  }
  return null;
}
