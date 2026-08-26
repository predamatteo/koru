import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../domain/entities/statistics_period.dart';
import '../../../platform/blocking_channel.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/screen_time_provider.dart';
import '../../providers/statistics_providers.dart';
import '../../widgets/koru_pull_to_refresh.dart';
import 'widgets/achievements_grid.dart';

/// Durata delle transizioni di layout (una card che entra o esce, un testo che
/// cambia). Corta di proposito: deve smussare il salto, non farsi guardare.
const Duration _kMorph = Duration(milliseconds: 240);

/// Durata del "conteggio" dei tempi verso il nuovo valore. Più lunga della
/// morph: è l'animazione che porta l'informazione, e su cifre che cambiano di
/// ore intere sotto i 400ms si legge di nuovo come uno scatto.
const Duration _kCount = Duration(milliseconds: 420);

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
            // Navigazione giorno per giorno: solo nella vista "Today". Nella
            // settimana lo stesso mestiere lo fa già il grafico per-giorno.
            _AnimatedSlot(
              visible: !isWeek,
              child: const Padding(
                padding: EdgeInsets.only(top: 10),
                child: _DayNavigator(),
              ),
            ),
            const SizedBox(height: 16),
            const _ScreenTimeCard(),
            const SizedBox(height: 16),
            // Drill-down per-giorno: visibile solo nella vista settimana,
            // dove ha senso confrontare i singoli giorni.
            _AnimatedSlot(
              visible: isWeek,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: _WeeklyUsageChart(),
              ),
            ),
            const _TopAppsCard(),
            const SizedBox(height: 16),
            const _InterventionsCard(),
            const SizedBox(height: 16),
            const AchievementsGrid(),
          ],
        ),
      ),
    );
  }
}

/// Slot che si apre e si chiude invece di apparire e sparire di colpo.
///
/// Dentro una `ListView` togliere un figlio fa saltare in su tutto quello che
/// sta sotto nello stesso frame: è metà dello "scatto" che si sente passando
/// da Today a This week. Qui l'altezza viene animata ([AnimatedSize], che
/// clippa il contenuto mentre si richiude) e il contenuto sfuma
/// ([AnimatedSwitcher]).
class _AnimatedSlot extends StatelessWidget {
  const _AnimatedSlot({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _kMorph,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _kMorph,
        child: visible
            ? child
            // `width: double.infinity` e non `SizedBox.shrink()`: a larghezza
            // zero la ListView non avrebbe più un vincolo orizzontale da dare
            // al figlio che entra, e la card comparirebbe alla sua larghezza
            // intrinseca prima di allargarsi.
            : const SizedBox(width: double.infinity, key: ValueKey('empty')),
      ),
    );
  }
}

/// Testo di una durata che **conta** verso il nuovo valore invece di saltarci.
///
/// È il punto in cui si vedeva di più lo scatto del cambio periodo: da "2h
/// 10m" a "14h 3m" in un frame. `TweenAnimationBuilder` riparte dal valore
/// corrente ogni volta che `end` cambia, quindi funziona anche se il dato
/// arriva in due tempi (valore vecchio → nuovo) come fanno i provider durante
/// il reload.
class _AnimatedDurationText extends StatelessWidget {
  const _AnimatedDurationText(this.ms, {required this.style});

  final int ms;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: ms.toDouble()),
      duration: _kCount,
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => Text(_fmtDurationMs(value.round()), style: style),
    );
  }
}

// ─── Day navigator (vista Today) ────────────────────────────────────────────

/// `‹ Yesterday ›`: sposta l'intera schermata su un giorno passato.
///
/// Si ferma a [StatisticsPeriod.maxDaysBack] perché oltre quella soglia
/// UsageStatsManager non ha più eventi e lo screen-time tornerebbe zero — che
/// l'utente leggerebbe come "quel giorno non ho usato niente" invece che come
/// "questo dato non esiste più". Meglio una freccia spenta.
class _DayNavigator extends ConsumerWidget {
  const _DayNavigator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(selectedDayOffsetProvider);
    void go(int delta) =>
        ref.read(selectedDayOffsetProvider.notifier).state = offset + delta;

    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          _NavArrow(
            icon: Icons.chevron_left,
            tooltip: 'Previous day',
            onTap: offset < StatisticsPeriod.maxDaysBack
                ? () => go(1)
                : null,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: _kMorph,
              child: Text(
                _dayLabel(_dayStartMsBack(offset)),
                key: ValueKey(offset),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: KoruColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _NavArrow(
            icon: Icons.chevron_right,
            tooltip: 'Next day',
            onTap: offset > 0 ? () => go(-1) : null,
          ),
          // Via di ritorno diretta: da sei giorni indietro servirebbero sei
          // tap sulla freccia. Compare solo quando c'è qualcosa da annullare,
          // e allargando la riga invece di apparirci dentro di colpo.
          AnimatedSize(
            duration: _kMorph,
            curve: Curves.easeOutCubic,
            child: offset > 0
                ? _TodayButton(
                    onTap: () => ref
                        .read(selectedDayOffsetProvider.notifier)
                        .state = 0,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_outlined, size: 15, color: KoruColors.primary),
              SizedBox(width: 5),
              Text(
                'Today',
                style: TextStyle(
                  color: KoruColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 22),
      color: KoruColors.primary,
      // Spenta e non nascosta: la freccia che sparisce sposta l'etichetta.
      disabledColor: KoruColors.textSecondary.withAlpha(70),
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
        borderRadius: BorderRadius.circular(18),
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
                  // Cambiare periodo azzera sia il giorno selezionato dal
                  // grafico sia la navigazione indietro: una selezione
                  // "appiccicata" sarebbe confondente, e soprattutto la
                  // settimana non è navigabile — restare a offset 3 vorrebbe
                  // dire mostrare una finestra che nessun comando può più
                  // spostare.
                  ref.read(selectedStatsDayProvider.notifier).state = null;
                  ref.read(selectedDayOffsetProvider.notifier).state = 0;
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
        key: ValueKey('day-${selDay.dayStartMs}'),
        style: const TextStyle(color: KoruColors.textSecondary, fontSize: 13),
      );
    } else {
      now = ref.watch(periodScreenTimeMsProvider).valueOrNull ?? 0;
      final prev =
          ref.watch(previousPeriodScreenTimeMsProvider).valueOrNull ?? 0;
      subtitle = _DeltaText(
        current: now,
        previous: prev,
        period: period,
        shifted: ref.watch(selectedDayOffsetProvider) > 0,
      );
    }

    return _Card(
      child: Column(
        children: [
          const _SectionLabel('Screen time', center: true),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _AnimatedDurationText(
              now,
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
          // Il sottotitolo cambia natura fra un periodo e l'altro (delta % vs
          // etichetta del giorno): senza cross-fade il salto si sente anche
          // se il numero sopra scorre.
          AnimatedSwitcher(duration: _kMorph, child: subtitle),
        ],
      ),
    );
  }
}

class _DeltaText extends StatelessWidget {
  const _DeltaText({
    required this.current,
    required this.previous,
    required this.period,
    required this.shifted,
  });
  final int current;
  final int previous;
  final StatisticsPeriod period;

  /// True se si sta guardando un giorno passato: il confronto non è più con
  /// "ieri" ma con il giorno prima di quello mostrato, e dirgli "yesterday"
  /// sarebbe una bugia piccola ma continua.
  final bool shifted;

  String _periodRef() => switch (period) {
    StatisticsPeriod.today => shifted ? 'the day before' : 'yesterday',
    StatisticsPeriod.week => 'last week',
  };

  @override
  Widget build(BuildContext context) {
    if (previous == 0) {
      final label = 'no data from ${_periodRef()}';
      return Text(
        label,
        // Chiave = testo: sta dentro un AnimatedSwitcher, e con una chiave
        // fissa il testo cambierebbe di colpo dentro il vecchio widget invece
        // di sfumare.
        key: ValueKey(label),
        style: const TextStyle(color: KoruColors.textSecondary, fontSize: 13),
      );
    }
    final diff = current - previous;
    final pct = (diff / previous * 100).round();
    final increased = pct > 0;
    final color = increased ? KoruColors.danger : KoruColors.success;
    final sign = increased ? '+' : '';
    final label = '$sign$pct% from ${_periodRef()}';
    return Text(
      label,
      key: ValueKey(label),
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
    // Animata su altezza E colore: le barre arrivano dopo il primo frame (il
    // provider settimanale è un Future) e cambiano tinta a ogni selezione —
    // entrambe le cose, senza animazione, si vedono come uno scatto.
    return AnimatedContainer(
      duration: _kMorph,
      curve: Curves.easeOutCubic,
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
          // La lista cambia in blocco quando cambia il periodo o il giorno:
          // cross-fade + altezza animata, altrimenti la card si accorcia di
          // colpo trascinandosi dietro tutto quello che ha sotto.
          AnimatedSize(
            duration: _kMorph,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: _kMorph,
              child: top.isEmpty
                  ? Padding(
                      key: const ValueKey('empty'),
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
                  : _TopAppsList(
                      key: ValueKey(
                        top.map((a) => a.packageName).join('|'),
                      ),
                      top: top,
                      labels: labels,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAppsList extends StatelessWidget {
  const _TopAppsList({super.key, required this.top, required this.labels});
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
            _AnimatedDurationText(
              ms,
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
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction.clamp(0, 1).toDouble()),
            duration: _kCount,
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: KoruColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                KoruColors.primary,
              ),
            ),
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
            // La fetta si muove invece di riapparire da un'altra parte: è il
            // contatore che cambia di più fra Oggi e Settimana.
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: total == 0 ? 0 : respected / total),
              duration: _kCount,
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => CustomPaint(
                painter: _DonutPainter(
                  respectedFraction: value,
                  hasData: total > 0,
                ),
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
            style: const TextStyle(color: KoruColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.respectedFraction, required this.hasData});

  /// Quota di blocchi rispettati, 0..1. È un double e non la coppia di conteggi
  /// perché il valore viene interpolato da un `TweenAnimationBuilder`.
  final double respectedFraction;

  /// False = nessun blocco nel periodo: si disegna solo l'anello di fondo.
  final bool hasData;

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

    if (!hasData) return;

    final respFraction = respectedFraction.clamp(0.0, 1.0);
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
      old.respectedFraction != respectedFraction || old.hasData != hasData;
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
        borderRadius: BorderRadius.circular(26),
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

/// Mezzanotte locale di [daysBack] giorni fa. Costruita per campi di calendario
/// (`DateTime(y, m, d - n)`) e non sottraendo 24 ore: a cavallo di un cambio di
/// ora legale la sottrazione finisce sul giorno sbagliato.
int _dayStartMsBack(int daysBack) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - daysBack).millisecondsSinceEpoch;
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
