import 'package:drift/drift.dart';

/// Prioridades do dia (no máximo três por dia; ver PrioritiesRepository).
@DataClassName('DailyPriority')
class DailyPriorities extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Dia a que a prioridade pertence (dias desde 01/01/1970).
  IntColumn get day => integer()();
  TextColumn get title => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
