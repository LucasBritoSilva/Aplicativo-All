import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/dates.dart';
import '../domain/task_sorting.dart';

TaskOrderKey taskKey(TaskItem t) => TaskOrderKey(
  id: t.id,
  done: t.done,
  priority: t.priority,
  dueDate: t.dueDate,
  createdAt: t.createdAt,
);

/// Subtarefa ainda não gravada (usada pelo formulário).
typedef SubtaskDraft = ({int? id, String title, bool done});

/// Tarefa com as suas subtarefas.
class TaskWithSubtasks {
  const TaskWithSubtasks(this.task, this.subtasks);

  final TaskItem task;
  final List<TaskSubtask> subtasks;

  int get subtasksDone => subtasks.where((s) => s.done).length;
}

class TasksRepository {
  TasksRepository(this._db);
  final AppDatabase _db;

  Future<List<TaskWithSubtasks>> _load() async {
    final tasks = sortTasks(await _db.select(_db.tasks).get(), taskKey);
    final subs =
        await (_db.select(_db.taskSubtasks)..orderBy([
              (s) => OrderingTerm.asc(s.position),
              (s) => OrderingTerm.asc(s.id),
            ]))
            .get();
    final byTask = <int, List<TaskSubtask>>{};
    for (final s in subs) {
      (byTask[s.taskId] ??= []).add(s);
    }
    return [
      for (final t in tasks) TaskWithSubtasks(t, byTask[t.id] ?? const []),
    ];
  }

  /// Todas as tarefas, já ordenadas por prioridade e prazo.
  Stream<List<TaskWithSubtasks>> watchSorted() =>
      _db.watchTables({_db.tasks, _db.taskSubtasks}, _load);

  /// Cria ou altera a tarefa e substitui as subtarefas, tudo de uma vez.
  Future<int> save({
    int? id,
    required String title,
    String? notes,
    required TaskPriority priority,
    DateTime? dueDate,
    List<SubtaskDraft> subtasks = const [],
  }) => _db.transaction(() async {
    final data = TasksCompanion(
      title: Value(title),
      notes: Value(notes),
      priority: Value(priority),
      dueDate: Value(dueDate == null ? null : dateOnly(dueDate)),
    );
    final taskId = id ?? await _db.into(_db.tasks).insert(data);
    if (id != null) {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(data);
    }
    await (_db.delete(
      _db.taskSubtasks,
    )..where((s) => s.taskId.equals(taskId))).go();
    for (final (i, s) in subtasks.indexed) {
      if (s.title.trim().isEmpty) continue;
      await _db
          .into(_db.taskSubtasks)
          .insert(
            TaskSubtasksCompanion.insert(
              taskId: taskId,
              title: s.title.trim(),
              done: Value(s.done),
              position: Value(i),
            ),
          );
    }
    return taskId;
  });

  /// Conclui ou reabre. A data de conclusão alimenta as estatísticas.
  Future<void> setDone(int id, bool done, {DateTime? now}) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          done: Value(done),
          completedAt: Value(done ? (now ?? DateTime.now()) : null),
        ),
      );

  Future<void> setSubtaskDone(int subtaskId, bool done) =>
      (_db.update(_db.taskSubtasks)..where((s) => s.id.equals(subtaskId)))
          .write(TaskSubtasksCompanion(done: Value(done)));

  Future<void> delete(int id) =>
      (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();

  Future<int> clearDone() =>
      (_db.delete(_db.tasks)..where((t) => t.done.equals(true))).go();
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(databaseProvider)),
);

final sortedTasksProvider = StreamProvider<List<TaskWithSubtasks>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchSorted(),
);
