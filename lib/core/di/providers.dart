import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/focus_usage_events_dao.dart';
import '../../data/database/daos/intention_usage_events_dao.dart';
import '../../data/database/daos/restricted_access_events_dao.dart';
import '../../data/local/hive_settings_service.dart';

/// Root provider for the Drift database. Must be overridden in main() with an
/// initialized [AppDatabase] instance (or disposed at app shutdown).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in main() before use.',
  );
});

/// Root provider for the Hive settings facade.
final hiveSettingsServiceProvider = Provider<HiveSettingsService>((ref) {
  throw UnimplementedError(
    'hiveSettingsServiceProvider must be overridden in main() before use.',
  );
});

// DAO shortcuts -------------------------------------------------------------

final restrictedAccessEventsDaoProvider = Provider<RestrictedAccessEventsDao>(
  (ref) => ref.watch(appDatabaseProvider).restrictedAccessEventsDao,
);

final intentionUsageEventsDaoProvider = Provider<IntentionUsageEventsDao>(
  (ref) => ref.watch(appDatabaseProvider).intentionUsageEventsDao,
);

final focusUsageEventsDaoProvider = Provider<FocusUsageEventsDao>(
  (ref) => ref.watch(appDatabaseProvider).focusUsageEventsDao,
);
