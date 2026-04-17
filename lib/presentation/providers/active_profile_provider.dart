import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/profile_types.dart';
import '../../core/utils/schedule_utils.dart';
import '../../data/models/profile_model.dart';
import 'profile_providers.dart';

/// Emette la lista di profili attivi nel momento corrente.
/// Re-evaluta ogni minuto + ogni volta che la lista profili cambia.
final activeProfilesProvider = StreamProvider<List<ProfileModel>>((ref) async* {
  final allProfiles = ref.watch(profilesProvider);
  final profiles = allProfiles.valueOrNull ?? const <ProfileModel>[];

  Iterable<ProfileModel> evaluate() sync* {
    final now = DateTime.now();
    for (final p in profiles) {
      if (!p.isEnabled) continue;
      if (p.data.pausedUntil < 0) continue;
      if (p.data.pausedUntil > 0 && p.data.pausedUntil > now.millisecondsSinceEpoch) {
        continue;
      }
      if (!ScheduleUtils.isTodayActive(p.dayFlags, now: now)) continue;

      if (ProfileType.hasType(p.typeCombinations, ProfileType.time) && p.intervals.isNotEmpty) {
        final inRange = p.intervals.any((iv) => ScheduleUtils.isNowInRange(
              fromMinutes: iv.fromMinutes,
              toMinutes: iv.toMinutes,
              now: now,
            ));
        if (!inRange) continue;
      }

      if (p.data.onUntil > 0 && now.millisecondsSinceEpoch > p.data.onUntil) continue;
      yield p;
    }
  }

  yield evaluate().toList(growable: false);
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    yield evaluate().toList(growable: false);
  }
});
