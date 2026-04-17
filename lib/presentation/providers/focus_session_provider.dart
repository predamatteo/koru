import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/focus_session_repository.dart';
import '../../platform/service_event_channel.dart';

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>(
  (ref) => FocusSessionRepository(ref.watch(appDatabaseProvider)),
);

/// Stream di QuickBlockTickEvent emessi dal native. Tutti gli altri eventi
/// (service state, blocking state, section detection) sono ignorati qui.
final quickBlockTickProvider = StreamProvider<QuickBlockTickEvent>((ref) async* {
  final events = ref.watch(platformChannelServiceProvider).events.events();
  await for (final event in events) {
    if (event is QuickBlockTickEvent) yield event;
  }
});
