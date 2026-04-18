import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/intention_usage_events.dart';

part 'intention_usage_events_dao.g.dart';

class IntentionUsageResult {
  IntentionUsageResult({required this.title, required this.usageCount});

  final String title;
  final int usageCount;
}

@DriftAccessor(tables: [IntentionUsageEvents])
class IntentionUsageEventsDao extends DatabaseAccessor<AppDatabase>
    with _$IntentionUsageEventsDaoMixin {
  IntentionUsageEventsDao(super.db);

  Future<void> insertEvent(IntentionUsageEventsCompanion event) =>
      into(intentionUsageEvents).insert(event);

  Future<int> getLifetimeIntentionsCount() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS total FROM intention_usage_events',
      readsFrom: {intentionUsageEvents},
    ).getSingle();
    return row.read<int>('total');
  }

  Stream<List<IntentionUsageResult>> watchIntentionsUsages(
    String fromDate,
    String toDate,
  ) {
    final query = customSelect(
      'SELECT intention_name AS title, COUNT(*) AS usage_count '
      'FROM intention_usage_events '
      'WHERE day_start_date BETWEEN ? AND ? '
      'GROUP BY intention_name ORDER BY usage_count DESC',
      variables: [
        Variable.withString(fromDate),
        Variable.withString(toDate),
      ],
      readsFrom: {intentionUsageEvents},
    );
    return query.watch().map(
          (rows) => rows
              .map(
                (row) => IntentionUsageResult(
                  title: row.read<String>('title'),
                  usageCount: row.read<int>('usage_count'),
                ),
              )
              .toList(),
        );
  }
}
