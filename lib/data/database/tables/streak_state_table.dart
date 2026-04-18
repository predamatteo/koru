import 'package:drift/drift.dart';

/// Stato corrente di una streak giornaliera. Una riga per ogni
/// [StreakId] (focus / mindful / clean). `lastIncrementedDay` è in
/// formato YYYY-MM-DD (day-key locale) per idempotenza: se un evento
/// rilevante arriva nello stesso giorno, non incrementa di nuovo.
class StreakState extends Table {
  TextColumn get id => text()();
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  IntColumn get longest => integer().withDefault(const Constant(0))();
  TextColumn get lastIncrementedDay => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
