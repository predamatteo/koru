import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/achievements_repository.dart';
import '../../data/repositories/streaks_repository.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/streak.dart';
import '../../domain/usecases/evaluate_achievements.dart';

final streaksRepositoryProvider = Provider<StreaksRepository>(
  (ref) => StreaksRepository(ref.watch(streaksDaoProvider)),
);

final achievementsRepositoryProvider = Provider<AchievementsRepository>(
  (ref) => AchievementsRepository(ref.watch(achievementsDaoProvider)),
);

/// Stream del singolo [StreakSnapshot]. Per mostrare il "current
/// effettivo" (che azzera se la streak è stata persa) usa
/// [StreaksRepository.effectiveCurrent].
final streakSnapshotProvider =
    StreamProvider.family<StreakSnapshot, StreakId>((ref, id) {
  return ref.watch(streaksRepositoryProvider).watch(id);
});

/// Stream degli id di achievement già sbloccati.
final unlockedAchievementIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref
      .watch(achievementsRepositoryProvider)
      .watchAll()
      .map((rows) => rows.map((r) => r.id).toSet());
});

/// Stats aggregate correnti (ricomputate on-demand da [buildAchievementStats]).
/// Esposte come FutureProvider così la UI può farci `.watch` ed essere
/// invalidata al bisogno (dopo trigger evaluator).
final achievementStatsProvider = FutureProvider<AchievementStats>((ref) async {
  return buildAchievementStats(ref);
});

/// Aggrega tutte le metriche lifetime necessarie per [evaluateAchievements].
Future<AchievementStats> buildAchievementStats(Ref ref) async {
  final db = ref.read(appDatabaseProvider);
  final focusDao = ref.read(focusUsageEventsDaoProvider);
  final intentionsDao = ref.read(intentionUsageEventsDaoProvider);
  final raeDao = ref.read(restrictedAccessEventsDaoProvider);
  final streaksRepo = ref.read(streaksRepositoryProvider);
  final platform = ref.read(platformChannelServiceProvider);

  final lifetimeMs = await focusDao.getLifetimeFocusMs();
  final now = DateTime.now();
  final today = dayKeyFor(now);
  final todayMs = await focusDao.watchFocusTimeUsage(today, today).first;

  final intentionsCount = await intentionsDao.getLifetimeIntentionsCount();
  final honestBlocks = await raeDao.getLifetimeHonestBlockCount();

  final focusStreak = await streaksRepo.current(StreakId.focus);
  final cleanStreak = await streaksRepo.current(StreakId.clean);

  final profiles = await db.getAllProfiles();

  final limits = await platform.blocking.getAppDailyLimits();
  final appsWithLimits = limits.values.where((v) => v > 0).length;

  final customOverlayRows = await db
      .customSelect(
        "SELECT COUNT(*) AS c FROM app_profile_relations "
        "WHERE overlay_config_json IS NOT NULL "
        "AND TRIM(overlay_config_json) != ''",
      )
      .getSingle();
  final customOverlayCount = customOverlayRows.read<int>('c');

  final strictMask = await platform.strictMode.getStrictModeOptions();
  final strictMode = strictMask > 0;

  return AchievementStats(
    totalFocusMinutes: (lifetimeMs / 60000).floor(),
    focusMinutesToday: (todayMs / 60000).floor(),
    focusStreakCurrent: StreaksRepository.effectiveCurrent(focusStreak, now),
    cleanStreakCurrent: StreaksRepository.effectiveCurrent(cleanStreak, now),
    intentionsCount: intentionsCount,
    honestBlocksCount: honestBlocks,
    profilesCount: profiles.length,
    appsWithLimitsCount: appsWithLimits,
    strictModeEnabled: strictMode,
    appsWithCustomOverlayCount: customOverlayCount,
  );
}

/// Broadcast stream che emette un [Achievement] ogni volta che il
/// valutatore sblocca qualcosa di nuovo. La UI ascolta per mostrare
/// un toast discreto.
class NewUnlocksController {
  final _controller = StreamController<Achievement>.broadcast();
  Stream<Achievement> get stream => _controller.stream;
  void emit(Achievement a) => _controller.add(a);
  void close() => _controller.close();
}

final newUnlocksControllerProvider = Provider<NewUnlocksController>((ref) {
  final c = NewUnlocksController();
  ref.onDispose(c.close);
  return c;
});

final newAchievementUnlocksStreamProvider = StreamProvider<Achievement>((ref) {
  return ref.watch(newUnlocksControllerProvider).stream;
});

/// Wrapper Notifier per esporre il trigger di valutazione sia dal
/// lato provider (evaluator side-effect) sia dalla UI via WidgetRef.
/// Evita il mismatch di tipi fra Ref e WidgetRef.
class AchievementEvaluationNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> trigger() async {
    try {
      final stats = await buildAchievementStats(ref);
      final repo = ref.read(achievementsRepositoryProvider);
      final newly = await evaluateAchievements(stats: stats, repo: repo);
      if (newly.isEmpty) return;
      final controller = ref.read(newUnlocksControllerProvider);
      for (final a in newly) {
        controller.emit(a);
      }
      ref.invalidate(achievementStatsProvider);
    } catch (_) {
      // fail silenzioso — gamification non deve crashare l'app
    }
  }
}

final achievementEvaluationProvider =
    NotifierProvider<AchievementEvaluationNotifier, void>(
  AchievementEvaluationNotifier.new,
);
