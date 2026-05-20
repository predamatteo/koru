import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/hive_keys.dart';
import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../core/di/providers.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/focus_whitelist_provider.dart';
import '../../widgets/koru_pull_to_refresh.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  int _work = 25;
  int _break = 5;
  int _cycles = 4;

  @override
  void initState() {
    super.initState();
    final hive = ref.read(hiveSettingsServiceProvider);
    _work = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroWorkMinutes,
      defaultValue: 25,
    );
    _break = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroBreakMinutes,
      defaultValue: 5,
    );
    _cycles = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroCycles,
      defaultValue: 4,
    );
  }

  Future<void> _persist() async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.put(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroWorkMinutes,
      _work,
    );
    await hive.put(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroBreakMinutes,
      _break,
    );
    await hive.put(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroCycles,
      _cycles,
    );
  }

  Future<void> _start() async {
    await _persist();
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    final whitelist = ref.read(focusWhitelistProvider(FocusMode.pomodoro));
    await blocking.startPomodoro(
      workPhase: Duration(minutes: _work),
      breakPhase: Duration(minutes: _break),
      cycles: _cycles,
      whitelist: whitelist.toList(growable: false),
    );
    if (mounted) context.pop();
  }

  Future<void> _stop() async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    await blocking.stopPomodoro();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tick = ref.watch(quickBlockTickProvider).valueOrNull;
    final isActive = tick?.isActive ?? false;
    final totalMinutes = (_work + _break) * _cycles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
          children: [
            if (isActive)
              _ActiveCard(tick: tick!, onStop: _stop)
            else ...[
              const _SectionLabel('Focus'),
              const SizedBox(height: 10),
              _DurationStepper(
                value: _work,
                min: 5,
                max: 90,
                step: 5,
                onChanged: (v) => setState(() => _work = v),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Break'),
              const SizedBox(height: 10),
              _DurationStepper(
                value: _break,
                min: 1,
                max: 30,
                step: 1,
                onChanged: (v) => setState(() => _break = v),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Cycles'),
              const SizedBox(height: 10),
              _DurationStepper(
                value: _cycles,
                min: 1,
                max: 12,
                step: 1,
                unit: 'cycles',
                onChanged: (v) => setState(() => _cycles = v),
              ),
              const SizedBox(height: 14),
              _SummaryCard(cycles: _cycles, totalMinutes: totalMinutes),
              const SizedBox(height: 24),
              const _SectionLabel('Whitelist'),
              const SizedBox(height: 10),
              _WhitelistCard(
                onTap: () => context.push('/focus/pomodoro/whitelist'),
              ),
              const SizedBox(height: 32),
              _StartButton(
                label: 'Start $_cycles\u00d7 ${_work}m / ${_break}m',
                onTap: _start,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Active card (durante la sessione) ──────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.tick, required this.onStop});
  final dynamic tick;
  final VoidCallback onStop;

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remainingMs = tick.remainingMs as int;
    final totalMs = tick.totalMs as int;
    final phase = tick.isPomodoroBreak as bool ? 'Break' : 'Focus';
    final progress = totalMs == 0 ? 0.0 : 1 - (remainingMs / totalMs);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SectionLabel(phase, center: true),
          const SizedBox(height: 14),
          Text(
            _fmt(remainingMs),
            style: const TextStyle(
              color: KoruColors.textPrimary,
              fontSize: 64,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cycle ${tick.currentCycle}/${tick.totalCycles}',
            style: const TextStyle(
              color: KoruColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: KoruColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                KoruColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: FilledButton.styleFrom(
                backgroundColor: KoruColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stepper / primitives ───────────────────────────────────────────────────

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.unit = 'minutes',
  });
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged((value - step).clamp(min, max).toInt()),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: KoruColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: KoruColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged((value + step).clamp(min, max).toInt()),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? KoruColors.primary.withAlpha(40)
          : KoruColors.surfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled
                ? KoruColors.primary
                : KoruColors.textSecondary.withAlpha(120),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.cycles, required this.totalMinutes});
  final int cycles;
  final int totalMinutes;

  String _formatTotal() {
    if (totalMinutes < 60) return '${totalMinutes}m';
    final h = totalMinutes / 60;
    final whole = h.floor();
    final frac = h - whole;
    if (frac < 0.05) return '${whole}h';
    return '${h.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KoruColors.surface.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 16,
            color: KoruColors.textSecondary.withAlpha(180),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$cycles cycles \u00b7 ${_formatTotal()} total',
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhitelistCard extends StatelessWidget {
  const _WhitelistCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.playlist_add_check,
            color: KoruColors.primary,
            size: 22,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allowed apps',
                  style: TextStyle(
                    color: KoruColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stay usable during work phases',
                  style: TextStyle(
                    color: KoruColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: KoruColors.textSecondary.withAlpha(140),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.play_arrow),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: KoruColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: container,
      ),
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
