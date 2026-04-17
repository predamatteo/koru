import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/intention_repository.dart';

final intentionRecorderProvider = Provider<IntentionRepository>(
  (ref) => IntentionRepository(ref.watch(appDatabaseProvider)),
);
