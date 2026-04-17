import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../providers/focus_session_provider.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(quickBlockTickProvider);
    final isActive = tickAsync.valueOrNull?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isActive) _ActiveBanner(tick: tickAsync.valueOrNull!),
          if (isActive) const SizedBox(height: 16),
          _FocusCard(
            icon: Icons.timer_outlined,
            title: 'Quick block',
            subtitle: 'Timer for a single focus stretch',
            onTap: () => context.push('/focus/quick'),
          ),
          const SizedBox(height: 12),
          _FocusCard(
            icon: Icons.hourglass_bottom_outlined,
            title: 'Pomodoro',
            subtitle: 'Work/break cycles',
            onTap: () => context.push('/focus/pomodoro'),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: KoruColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: KoruColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KoruColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.tick});

  final dynamic tick;

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
    return Card(
      color: KoruColors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$phase in progress',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(_fmt(remainingMs),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(letterSpacing: 4)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}
