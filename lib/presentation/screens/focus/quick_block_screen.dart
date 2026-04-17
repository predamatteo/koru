import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/di/providers.dart';
import '../../providers/focus_session_provider.dart';

class QuickBlockScreen extends ConsumerStatefulWidget {
  const QuickBlockScreen({super.key});

  @override
  ConsumerState<QuickBlockScreen> createState() => _QuickBlockScreenState();
}

class _QuickBlockScreenState extends ConsumerState<QuickBlockScreen> {
  static const _presets = <int>[15, 25, 60, 120]; // minutes
  int _customMinutes = 30;

  Future<void> _start(int minutes) async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    await blocking.startQuickBlock(Duration(minutes: minutes));
  }

  Future<void> _stop() async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    await blocking.stopQuickBlock();
    // Log completed session approssimata: minutes elapsed dall'ultimo tick.
    // (porting più preciso in Step 15)
  }

  @override
  Widget build(BuildContext context) {
    final tickAsync = ref.watch(quickBlockTickProvider);
    final tick = tickAsync.valueOrNull;
    final isActive = tick?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Quick block')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isActive) ...[
              _CircularTimer(
                remainingMs: tick!.remainingMs,
                totalMs: tick.totalMs,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                style: FilledButton.styleFrom(
                  backgroundColor: KoruColors.danger,
                ),
              ),
            ] else ...[
              Text(
                'Choose a duration',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _presets)
                    OutlinedButton(
                      onPressed: () => _start(m),
                      child: Text('$m min'),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Custom: $_customMinutes minutes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _customMinutes.toDouble(),
                min: 5,
                max: 240,
                divisions: 47,
                label: '$_customMinutes min',
                onChanged: (v) => setState(() => _customMinutes = v.round()),
              ),
              FilledButton.icon(
                onPressed: () => _start(_customMinutes),
                icon: const Icon(Icons.play_arrow),
                label: Text('Start $_customMinutes min'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircularTimer extends StatelessWidget {
  const _CircularTimer({required this.remainingMs, required this.totalMs});

  final int remainingMs;
  final int totalMs;

  String get _remaining {
    final s = remainingMs ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalMs == 0 ? 0.0 : 1 - (remainingMs / totalMs);
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              strokeWidth: 8,
              color: KoruColors.primary,
              backgroundColor: KoruColors.surface,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _remaining,
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(letterSpacing: 4),
              ),
              Text(
                'remaining',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KoruColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
