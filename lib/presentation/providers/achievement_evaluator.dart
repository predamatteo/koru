import 'package:flutter/widgets.dart';
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
/// - Boot catch-up: valutazione una-tantum allo start per coprire dati
///   esistenti (focus sessions, profili, strict mode) presenti prima
///   dell'installazione del sistema achievement.
/// - Fine sessione focus (tick isActive true→false) →
///   StreaksRepository.markToday(focus) + eval achievements.
/// - Blocco triggered (BlockingStateEvent isBlocking=true) →
///   eval achievements (Honest Block count cresce).
/// - Altri trigger (mood check-in, intention chosen, profile created,
///   strict mode toggle, app limit set, overlay custom) sono lanciati
///   direttamente dai rispettivi flow.
final achievementEvaluatorProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  final streaksRepo = ref.read(streaksRepositoryProvider);

  // Boot catch-up: dopo un micro-delay (per permettere a DI + DB di
  // essere pronti) valuta una volta. Questo copre installazioni su
  // dati pre-esistenti e utenti che hanno eventi storici ma mai
  // triggerato l'evaluator.
  Future<void>.delayed(const Duration(seconds: 1), () {
    try {
      ref.read(achievementEvaluationProvider.notifier).trigger();
    } catch (_) {}
  });

  // Resume catch-up: ogni volta che l'app torna foreground, rivaluta
  // (idempotente: insertOrIgnore, no-op se già sbloccato).
  final observer = _ResumeObserver(() {
    try {
      ref.read(achievementEvaluationProvider.notifier).trigger();
    } catch (_) {}
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));

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

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
