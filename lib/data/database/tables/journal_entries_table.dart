import 'package:drift/drift.dart';

/// Journal entries: un'annotazione libera associata a un giorno.
/// Pensata come complemento al mood check-in — se il mood è "come mi sento
/// oggi" (1-5), il journal è "perché / cosa scriverei su questo momento".
/// Primary key = dayStartDate (YYYY-MM-DD) → una entry per giorno max,
/// upsert quando l'utente ri-scrive.
class JournalEntries extends Table {
  TextColumn get dayStartDate => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {dayStartDate};
}
