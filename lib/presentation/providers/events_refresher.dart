import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/service_event_channel.dart';
import 'mood_provider.dart';
import 'statistics_providers.dart';

/// Ascolta lo stream di eventi native (BLOCKING_STATE / IN_APP_SECTION_DETECTED)
/// e invalida i provider di statistiche così il conteggio "Blocks" si
/// aggiorna in real-time anche se il native scrive direttamente su SQLite
/// (bypassando il tracking automatico di Drift.watch).
final blockingEventsRefresherProvider = Provider<void>((ref) {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  final sub = events.listen((event) {
    final shouldInvalidate = (event is BlockingStateEvent && event.isBlocking) ||
        event is UnknownServiceEvent &&
            event.raw['type'] == 'IN_APP_SECTION_DETECTED';
    if (shouldInvalidate) {
      ref.invalidate(blockTriggeredCountProvider);
      ref.invalidate(blockSkippedCountProvider);
      ref.invalidate(perAppBreakdownProvider);
      ref.invalidate(topIntentionsProvider);
      ref.invalidate(focusTimeMsProvider);
      ref.invalidate(todayMoodProvider);
    }
  });
  ref.onDispose(sub.cancel);
});
