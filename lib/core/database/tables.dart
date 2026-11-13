import 'package:drift/drift.dart';

import '../../features/shopping/domain/shopping_section.dart';
import '../../features/tasks/domain/task_sorting.dart';

/// Lista de mercado, organizada pelas seções do mercado.
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get quantity => text().nullable()();
  TextColumn get section => textEnum<ShoppingSection>()();
  BoolColumn get bought => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tarefas com prioridade e prazo.
@DataClassName('TaskItem')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get priority => textEnum<TaskPriority>()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Quando foi concluída (usado nas estatísticas); nulo se está pendente.
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Subtarefas de uma tarefa.
class TaskSubtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// Lembretes com notificação em horário exato.
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
}

/// Hábitos com meta semanal.
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

/// Metas de longo prazo.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get currentValue => real().withDefault(const Constant(0))();
  RealColumn get targetValue => real()();
  TextColumn get unit => text().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Anotações (as ideias por voz também viram anotações).
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text()();
  BoolColumn get fromVoice => boolean().withDefault(const Constant(false))();

  /// Notas fixadas aparecem no topo da lista.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Imagens anexadas às notas. O arquivo fica na pasta privada do app
/// ([path]); a linha some junto com a nota.
class NoteImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
