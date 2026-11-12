import 'package:drift/drift.dart';

import '../../features/shopping/domain/shopping_section.dart';
import '../../features/tasks/domain/task_sorting.dart';

/// 1. Lista de compras.
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get quantity => text().nullable()();
  TextColumn get section => textEnum<ShoppingSection>()();
  BoolColumn get bought => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 2. Itens da rotina diária. [doneOn] guarda o dia em que foi marcado:
/// o item só conta como feito se esse dia for hoje.
class RoutineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get doneOn => dateTime().nullable()();
}

/// 3. Eventos da agenda (somente locais).
@DataClassName('AgendaEvent')
class AgendaEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
}

/// 4. Tarefas com prioridade e prazo.
@DataClassName('TaskItem')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get priority => textEnum<TaskPriority>()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 5. Lembretes com notificação em horário exato.
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
}

/// 6. Hábitos com meta semanal.
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get weeklyTarget => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Dias em que cada hábito foi feito.
class HabitChecks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get day => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, day},
  ];
}

/// 7. Metas de longo prazo.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get currentValue => real().withDefault(const Constant(0))();
  RealColumn get targetValue => real()();
  TextColumn get unit => text().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 8 e 9. Anotações (as ideias por voz também viram anotações).
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text()();
  BoolColumn get fromVoice => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
