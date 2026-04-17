import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/preset_repository.dart';
import 'profile_providers.dart';

final presetRepositoryProvider = Provider<PresetRepository>(
  (ref) => PresetRepository(ref.watch(profileRepositoryProvider)),
);

final allPresetsProvider = FutureProvider<List<KoruPreset>>(
  (ref) => ref.watch(presetRepositoryProvider).loadAll(),
);
