import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/focus_usage_events.dart';

part 'focus_usage_events_dao.g.dart';

@DriftAccessor(tables: [FocusUsageEvents])
class FocusUsageEventsDao extends DatabaseAccessor<AppDatabase>
    with _$FocusUsageEventsDaoMixin {
  FocusUsageEventsDao(super.db);

  Future<void> insertEvent(FocusUsageEventsCompanion event) =>
      into(focusUsageEvents).insert(event);

  /// Totale lifetime (in ms) di tutte le sessioni focus registrate.
  Future<int> getLifetimeFocusMs() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(duration_in_ms), 0) AS total FROM focus_usage_events',
      readsFrom: {focusUsageEvents},
    ).getSingle();
    return row.read<int>('total');
  }

  Stream<int> watchFocusTimeUsage(String fromDate, String toDate) {
    final query = customSelect(
      'SELECT COALESCE(SUM(duration_in_ms), 0) AS total '
      'FROM focus_usage_events '
      'WHERE day_start_date BETWEEN ? AND ?',
      variables: [
        Variable.withString(fromDate),
        Variable.withString(toDate),
      ],
      readsFrom: {focusUsageEvents},
    );
    return query.watchSingle().map((row) => row.read<int>('total'));
  }
}
