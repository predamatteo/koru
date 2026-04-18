import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/di/providers.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/focus_whitelist_provider.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  int _workMinutes = 25;
  int _breakMinutes = 5;
  int _cycles = 4;

  Future<void> _start() async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    final whitelist = ref.read(focusWhitelistProvider(FocusMode.pomodoro));
    await blocking.startPomodoro(
      workPhase: Duration(minutes: _workMinutes),
      breakPhase: Duration(minutes: _breakMinutes),
      cycles: _cycles,
      whitelist: whitelist.toList(growable: false),
    );
  }

  Future<void> _stop() async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    await blocking.stopPomodoro();
  }

  @override
  Widget build(BuildContext context) {
    final tick = ref.watch(quickBlockTickProvider).valueOrNull;
    final isActive = tick?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        actions: [
          IconButton(
            tooltip: 'Whitelist',
            icon: const Icon(Icons.playlist_add_check),
            onPressed: () => context.push('/focus/pomodoro/whitelist'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isActive ? _buildActive(tick!) : _buildSetup(),
      ),
    );
  }

  Widget _buildSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MinutesSlider(
          label: 'Focus',
          value: _workMinutes,
          min: 10,
          max: 90,
          onChanged: (v) => setState(() => _workMinutes = v),
        ),
        const SizedBox(height: 16),
        _MinutesSlider(
          label: 'Break',
          value: _breakMinutes,
          min: 3,
          max: 30,
          onChanged: (v) => setState(() => _breakMinutes = v),
        ),
        const SizedBox(height: 16),
        _MinutesSlider(
          label: 'Cycles',
          value: _cycles,
          min: 1,
          max: 8,
          unit: '',
          onChanged: (v) => setState(() => _cycles = v),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(
            'Start — ${_cycles}x ${_workMinutes}m / ${_breakMinutes}m',
          ),
        ),
      ],
    );
  }

  Widget _buildActive(dynamic tick) {
    final phase = tick.isPomodoroBreak as bool ? 'Break' : 'Focus';
    final remaining = tick.remainingMs as int;
    final s = remaining ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    final timeStr =
        '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(phase, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            timeStr,
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(letterSpacing: 6),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Cycle ${tick.currentCycle}/${tick.totalCycles}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KoruColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        FilledButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: FilledButton.styleFrom(backgroundColor: KoruColors.danger),
        ),
      ],
    );
  }
}

class _MinutesSlider extends StatelessWidget {
  const _MinutesSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = 'min',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · $value${unit.isEmpty ? '' : ' $unit'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value${unit.isEmpty ? '' : ' $unit'}',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
