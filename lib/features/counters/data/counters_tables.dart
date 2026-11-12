import 'package:drift/drift.dart';

/// Contadores de dias: quanto falta para uma data ou quanto passou desde ela.
class DayCounters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// Data do acontecimento (dias desde 01/01/1970).
  IntColumn get day => integer()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
