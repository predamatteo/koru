import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/streak.dart';
import '../../platform/service_event_channel.dart';
import 'achievements_provider.dart';

/// Ascolta gli eventi "trigger" e richiama il valutatore di achievement
/// + streak mark idempotente. Side-effect provider, sempre-attivo
/// (watchato dal root in `app.dart`).
///
/// Hook implementati:
/// - Fine sessione focus (tick isActive true→false) →
///   StreaksRepository.markToday(focus) + eval achievements.
/// - Blocco triggered (BlockingStateEvent isBlocking=true) →
///   eval achievements (Honest Block count cresce).
/// - Altri trigger (mood check-in, intention chosen, profile created,
///   strict mode toggle, app limit set, overlay custom) sono lanciati
///   direttamente dai rispettivi flow via `triggerAchievementEvaluation`.
final achievementEvaluatorProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  final streaksRepo = ref.read(streaksRepositoryProvider);

  bool? lastTickIsActive;

  final sub = events.listen((event) async {
    if (event is QuickBlockTickEvent) {
      final was = lastTickIsActive;
      lastTickIsActive = event.isActive;
      if (was == true && !event.isActive) {
        // sessione focus appena chiusa → focus streak + achievements
        await streaksRepo.markToday(StreakId.focus);
        await ref.read(achievementEvaluationProvider.notifier).trigger();
      }
    } else if (event is BlockingStateEvent && event.isBlocking) {
      // nuovo blocco triggered → honest block count crescerà al prossimo eval
      await ref.read(achievementEvaluationProvider.notifier).trigger();
    }
  });
  ref.onDispose(sub.cancel);
});
