import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../domain/entities/achievement.dart';
import '../../../providers/achievements_provider.dart';

/// Grid compatta con i primi 6 achievement (mix di sbloccati e prossimi
/// da sbloccare per invogliare). Tappando "View all" si va alla full list.
class AchievementsGrid extends ConsumerWidget {
  const AchievementsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(unlockedAchievementIdsProvider);
    final unlocked = unlockedAsync.valueOrNull ?? const <String>{};

    final sorted = [...kAchievementCatalog]..sort((a, b) {
        final aU = unlocked.contains(a.id) ? 0 : 1;
        final bU = unlocked.contains(b.id) ? 0 : 1;
        return aU - bU;
      });
    final preview = sorted.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Achievements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${unlocked.length}/${kAchievementCatalog.length}',
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.push('/stats/achievements'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: [
            for (final a in preview)
              _AchievementBadge(
                achievement: a,
                unlocked: unlocked.contains(a.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.achievement,
    required this.unlocked,
  });

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final tint = unlocked ? _tintFor(achievement.category) : KoruColors.surface;
    final iconColor =
        unlocked ? KoruColors.textPrimary : KoruColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tint.withAlpha(unlocked ? 60 : 40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? tint.withAlpha(120)
              : KoruColors.surface.withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(achievement.icon, color: iconColor, size: 28),
          const SizedBox(height: 6),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: iconColor,
              fontWeight: unlocked ? FontWeight.w600 : FontWeight.w400,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

Color _tintFor(AchievementCategory c) => switch (c) {
      AchievementCategory.focus => KoruColors.primary,
      AchievementCategory.consistency => KoruColors.secondary,
      AchievementCategory.discipline => KoruColors.danger,
      AchievementCategory.setup => KoruColors.textSecondary,
    };
