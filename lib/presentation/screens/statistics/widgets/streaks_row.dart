import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../data/repositories/streaks_repository.dart';
import '../../../../domain/entities/streak.dart';
import '../../../providers/achievements_provider.dart';

/// Row orizzontale con chip streak (🔥 Focus / 🌿 Mindful / ✨ Clean).
/// Mostra `current` effettivo (azzerato se persa) e indicatore sottile
/// quando "at risk" (streak mantenuta solo se marchi oggi).
class StreaksRow extends ConsumerWidget {
  const StreaksRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _StreakChip(
            id: StreakId.focus,
            emoji: '🔥',
            label: 'Focus',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StreakChip(
            id: StreakId.mindful,
            emoji: '🌿',
            label: 'Mindful',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StreakChip(
            id: StreakId.clean,
            emoji: '✨',
            label: 'Clean',
          ),
        ),
      ],
    );
  }
}

class _StreakChip extends ConsumerWidget {
  const _StreakChip({
    required this.id,
    required this.emoji,
    required this.label,
  });

  final StreakId id;
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(streakSnapshotProvider(id));
    final snapshot = async.valueOrNull ?? StreakSnapshot.empty(id);
    final now = DateTime.now();
    final current = StreaksRepository.effectiveCurrent(snapshot, now);
    final today = dayKeyFor(now);
    final notYetToday =
        current > 0 && snapshot.lastIncrementedDay != today;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: notYetToday
            ? Border.all(color: KoruColors.secondary.withAlpha(100))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                '$current',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: KoruColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          if (snapshot.longest > 0)
            Text(
              'best ${snapshot.longest}',
              style: const TextStyle(
                fontSize: 10,
                color: KoruColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
