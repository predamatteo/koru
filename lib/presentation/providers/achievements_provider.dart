import 'dart:async';
import 'dart:developer' as developer;

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

  final now = DateTime.now();
  final today = dayKeyFor(now);

  // PERF (F2.5): metriche indipendenti lanciate in parallelo invece che in
  // sequenza. `Future.wait` (eagerError:false di default) attende TUTTE le
  // future anche se una fallisce, poi rilancia il primo errore → nessuna
  // rejection orfana; i singoli `await` successivi sono già completi e quindi
  // restano TIPIZZATI (nessun cast).
  final lifetimeMsF = focusDao.getLifetimeFocusMs();
  final todayMsF = focusDao.watchFocusTimeUsage(today, today).first;
  final intentionsCountF = intentionsDao.getLifetimeIntentionsCount();
  final honestBlocksF = raeDao.getLifetimeHonestBlockCount();
  final focusStreakF = streaksRepo.current(StreakId.focus);
  final cleanStreakF = streaksRepo.current(StreakId.clean);
  final profilesF = db.getAllProfiles();
  final limitsF = platform.blocking.getAppDailyLimits();
  final customOverlayF = db.customSelect(
    "SELECT COUNT(*) AS c FROM app_profile_relations "
    "WHERE overlay_config_json IS NOT NULL "
    "AND TRIM(overlay_config_json) != ''",
  ).getSingle();
  final strictMaskF = platform.strictMode.getStrictModeOptions();

  await Future.wait<Object?>([
    lifetimeMsF,
    todayMsF,
    intentionsCountF,
    honestBlocksF,
    focusStreakF,
    cleanStreakF,
    profilesF,
    limitsF,
    customOverlayF,
    strictMaskF,
  ]);

  final lifetimeMs = await lifetimeMsF;
  final todayMs = await todayMsF;
  final intentionsCount = await intentionsCountF;
  final honestBlocks = await honestBlocksF;
  final focusStreak = await focusStreakF;
  final cleanStreak = await cleanStreakF;
  final profiles = await profilesF;
  final limits = await limitsF;
  final customOverlayRows = await customOverlayF;
  final strictMask = await strictMaskF;

  final appsWithLimits = limits.values.where((v) => v.minutes > 0).length;
  final customOverlayCount = customOverlayRows.read<int>('c');
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

  Future<void>? _inFlight;
  bool _dirty = false;

  /// Coalescing: boot catch-up, resume e gli eventi (focus-end, block) possono
  /// chiamare [trigger] ravvicinati, ognuno dei quali rieseguirebbe l'intero
  /// [buildAchievementStats] (molte query DB + 2 platform call). Se una
  /// valutazione è già in corso ne riusiamo il Future invece di lanciarne
  /// un'altra in parallelo.
  ///
  /// `_dirty`: una valutazione in volo ha già fatto il suo snapshot DB, quindi
  /// NON vede le write arrivate dopo (es. `markToday` del focus appena chiuso
  /// in achievement_evaluator, eseguita prima di trigger()). Se arriva un nuovo
  /// trigger mentre siamo in volo lo marchiamo "sporco" e, al completamento,
  /// lanciamo UNA valutazione fresca che vede lo stato aggiornato — così lo
  /// sblocco non viene solo posticipato al prossimo evento. Gli unlock sono
  /// idempotenti, quindi una eval in più è innocua.
  Future<void> trigger() {
    final existing = _inFlight;
    if (existing != null) {
      _dirty = true;
      return existing;
    }
    final run = _evaluate().whenComplete(() {
      _inFlight = null;
      if (_dirty) {
        _dirty = false;
        trigger(); // re-coalesce: riassegna _inFlight; un terzo trigger ricoalesce
      }
    });
    _inFlight = run;
    return run;
  }

  Future<void> _evaluate() async {
    try {
      final stats = await buildAchievementStats(ref);
      developer.log(
        'stats: focusLife=${stats.totalFocusMinutes}min '
        'focusToday=${stats.focusMinutesToday}min '
        'focusStreak=${stats.focusStreakCurrent} '
        'profiles=${stats.profilesCount} '
        'limits=${stats.appsWithLimitsCount} '
        'strict=${stats.strictModeEnabled} '
        'overlay=${stats.appsWithCustomOverlayCount}',
        name: 'AchEval',
      );
      final repo = ref.read(achievementsRepositoryProvider);
      final newly = await evaluateAchievements(stats: stats, repo: repo);
      developer.log(
        'unlocked ${newly.length} new: ${newly.map((a) => a.id).join(",")}',
        name: 'AchEval',
      );
      if (newly.isEmpty) return;
      final controller = ref.read(newUnlocksControllerProvider);
      for (final a in newly) {
        controller.emit(a);
      }
      ref.invalidate(achievementStatsProvider);
    } catch (e, st) {
      developer.log(
        'trigger() failed',
        name: 'AchEval',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final achievementEvaluationProvider =
    NotifierProvider<AchievementEvaluationNotifier, void>(
  AchievementEvaluationNotifier.new,
);
