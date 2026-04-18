import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/restricted_access_events.dart';

part 'restricted_access_events_dao.g.dart';

class PerAppStatResult {
  PerAppStatResult({
    required this.packageName,
    required this.count,
    required this.eventType,
  });

  final String packageName;
  final int count;
  final int eventType;
}

@DriftAccessor(tables: [RestrictedAccessEvents])
class RestrictedAccessEventsDao extends DatabaseAccessor<AppDatabase>
    with _$RestrictedAccessEventsDaoMixin {
  RestrictedAccessEventsDao(super.db);

  Future<void> insertEvent(RestrictedAccessEventsCompanion event) =>
      into(restrictedAccessEvents).insert(event);

  Future<int> countEventsByTypeInRange(
    int eventType,
    String fromDate,
    String toDate,
  ) async {
    final query = customSelect(
      'SELECT COUNT(*) AS c FROM restricted_access_events '
      'WHERE event_type = ? AND day_start_date BETWEEN ? AND ?',
      variables: [
        Variable.withInt(eventType),
        Variable.withString(fromDate),
        Variable.withString(toDate),
      ],
      readsFrom: {restrictedAccessEvents},
    );
    final row = await query.getSingle();
    return row.read<int>('c');
  }

  /// Lifetime count di eventi BLOCK_TRIGGERED (eventType=0) — usato
  /// come "honest block count" (blocchi che l'utente NON ha bypassato).
  Future<int> getLifetimeHonestBlockCount() async {
    final query = customSelect(
      'SELECT COUNT(*) AS c FROM restricted_access_events WHERE event_type = 0',
      readsFrom: {restrictedAccessEvents},
    );
    final row = await query.getSingle();
    return row.read<int>('c');
  }

  Stream<int> watchCountEventsByTypeInRange(
    int eventType,
    String fromDate,
    String toDate,
  ) {
    final query = customSelect(
      'SELECT COUNT(*) AS c FROM restricted_access_events '
      'WHERE event_type = ? AND day_start_date BETWEEN ? AND ?',
      variables: [
        Variable.withInt(eventType),
        Variable.withString(fromDate),
        Variable.withString(toDate),
      ],
      readsFrom: {restrictedAccessEvents},
    );
    return query.watchSingle().map((row) => row.read<int>('c'));
  }

  Stream<int> watchCountByRestrictionTypeInRange(
    int restrictionType,
    String fromDate,
    String toDate,
  ) {
    final query = customSelect(
      'SELECT COUNT(*) AS c FROM restricted_access_events '
      'WHERE restriction_type = ? AND day_start_date BETWEEN ? AND ?',
      variables: [
        Variable.withInt(restrictionType),
        Variable.withString(fromDate),
        Variable.withString(toDate),
      ],
      readsFrom: {restrictedAccessEvents},
    );
    return query.watchSingle().map((row) => row.read<int>('c'));
  }

  Stream<List<PerAppStatResult>> watchPerAppBreakdown(
    String fromDate,
    String toDate,
  ) {
    final query = customSelect(
      'SELECT package_name, COUNT(*) AS cnt, event_type '
      'FROM restricted_access_events '
      'WHERE day_start_date BETWEEN ? AND ? '
      'GROUP BY package_name, event_type '
      'ORDER BY cnt DESC',
      variables: [
        Variable.withString(fromDate),
        Variable.withString(toDate),
      ],
      readsFrom: {restrictedAccessEvents},
    );
    return query.watch().map(
          (rows) => rows
              .map(
                (row) => PerAppStatResult(
                  packageName: row.read<String>('package_name'),
                  count: row.read<int>('cnt'),
                  eventType: row.read<int>('event_type'),
                ),
              )
              .toList(),
        );
  }
}
