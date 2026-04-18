import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../domain/entities/achievement.dart';
import '../../../domain/usecases/evaluate_achievements.dart';
import '../../providers/achievements_provider.dart';

/// Schermata full list degli achievement, raggruppati per categoria,
/// con progress bar "X / target" per ciascuno.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(unlockedAchievementIdsProvider);
    final statsAsync = ref.watch(achievementStatsProvider);

    final unlocked = unlockedAsync.valueOrNull ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (stats) {
          final byCategory = <AchievementCategory, List<Achievement>>{};
          for (final a in kAchievementCatalog) {
            byCategory.putIfAbsent(a.category, () => []).add(a);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
            children: [
              _HeaderCard(
                unlockedCount: unlocked.length,
                totalCount: kAchievementCatalog.length,
              ),
              const SizedBox(height: 16),
              for (final entry in byCategory.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(
                    _categoryLabel(entry.key).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: KoruColors.textSecondary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                for (final a in entry.value)
                  _AchievementTile(
                    achievement: a,
                    unlocked: unlocked.contains(a.id),
                    progress: achievementProgress(a, stats),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _categoryLabel(AchievementCategory c) => switch (c) {
      AchievementCategory.focus => 'Focus',
      AchievementCategory.consistency => 'Consistency',
      AchievementCategory.discipline => 'Discipline',
      AchievementCategory.setup => 'Setup',
    };

Color _tintFor(AchievementCategory c) => switch (c) {
      AchievementCategory.focus => KoruColors.primary,
      AchievementCategory.consistency => KoruColors.secondary,
      AchievementCategory.discipline => KoruColors.danger,
      AchievementCategory.setup => KoruColors.textSecondary,
    };

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.unlockedCount,
    required this.totalCount,
  });

  final int unlockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final pct = totalCount == 0 ? 0.0 : unlockedCount / totalCount;
    return Card(
      color: KoruColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$unlockedCount',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: KoruColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  ' / $totalCount unlocked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: KoruColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: KoruColors.backgroundBase,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(KoruColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.progress,
  });

  final Achievement achievement;
  final bool unlocked;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final tint = _tintFor(achievement.category);
    final fraction =
        achievement.target == 0 ? 0.0 : (progress / achievement.target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KoruColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked ? tint.withAlpha(120) : KoruColors.surface,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint.withAlpha(unlocked ? 60 : 30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                achievement.icon,
                color: unlocked ? tint : KoruColors.textSecondary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: unlocked
                          ? KoruColors.textPrimary
                          : KoruColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KoruColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 4,
                            backgroundColor: KoruColors.backgroundBase,
                            valueColor: AlwaysStoppedAnimation<Color>(tint),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress/${achievement.target}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: KoruColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (unlocked)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: tint, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
