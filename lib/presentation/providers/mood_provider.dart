import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/mood_repository.dart';

final moodRepositoryProvider =
    Provider<MoodRepository>((ref) => MoodRepository(ref.watch(appDatabaseProvider)));

final todayMoodProvider = FutureProvider<MoodCheckIn?>((ref) {
  return ref.watch(moodRepositoryProvider).getForToday();
});
