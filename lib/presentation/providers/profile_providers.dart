import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    db: ref.watch(appDatabaseProvider),
    channel: ref.watch(platformChannelServiceProvider).profile,
  );
});

final profilesProvider = StreamProvider<List<ProfileModel>>((ref) {
  return ref.watch(profileRepositoryProvider).watchAllProfiles();
});

final profileByIdProvider =
    FutureProvider.family<ProfileModel?, int>((ref, id) async {
  return ref.watch(profileRepositoryProvider).getProfileWithRelations(id);
});
