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

class TasksRepository {
  TasksRepository(this._db);
  final AppDatabase _db;

  /// Todas as tarefas, já ordenadas por prioridade e prazo.
  Stream<List<TaskItem>> watchSorted() => _db
      .select(_db.tasks)
      .watch()
      .map((rows) => sortTasks(rows, taskKey));

  Future<void> save({
    int? id,
    required String title,
    String? notes,
    required TaskPriority priority,
    DateTime? dueDate,
  }) async {
    final data = TasksCompanion(
      title: Value(title),
      notes: Value(notes),
      priority: Value(priority),
      dueDate: Value(dueDate == null ? null : dateOnly(dueDate)),
    );
    if (id == null) {
      await _db.into(_db.tasks).insert(data);
    } else {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(data);
    }
  }

  Future<void> setDone(int id, bool done) => (_db.update(
    _db.tasks,
  )..where((t) => t.id.equals(id))).write(TasksCompanion(done: Value(done)));

  Future<void> delete(int id) =>
      (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();

  Future<int> clearDone() =>
      (_db.delete(_db.tasks)..where((t) => t.done.equals(true))).go();
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(databaseProvider)),
);

final sortedTasksProvider = StreamProvider<List<TaskItem>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchSorted(),
);
