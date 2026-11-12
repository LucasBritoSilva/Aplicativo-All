import 'package:app_pessoal/features/tasks/domain/task_sorting.dart';
import 'package:flutter_test/flutter_test.dart';

TaskOrderKey _t(
  int id, {
  TaskPriority priority = TaskPriority.media,
  DateTime? due,
  bool done = false,
  DateTime? created,
}) => TaskOrderKey(
  id: id,
  done: done,
  priority: priority,
  dueDate: due,
  createdAt: created ?? DateTime(2026, 1, 1),
);

List<int> _ids(List<TaskOrderKey> list) => [for (final t in list) t.id];

void main() {
  group('sortTasks', () {
    test('ordena por prioridade: alta, média, baixa', () {
      final sorted = sortTasks([
        _t(1, priority: TaskPriority.baixa),
        _t(2, priority: TaskPriority.alta),
        _t(3, priority: TaskPriority.media),
      ], (t) => t);
      expect(_ids(sorted), [2, 3, 1]);
    });

    test('mesma prioridade: prazo mais próximo primeiro, sem prazo no fim', () {
      final sorted = sortTasks([
        _t(1),
        _t(2, due: DateTime(2026, 11, 20)),
        _t(3, due: DateTime(2026, 11, 12)),
        _t(4, due: DateTime(2026, 11, 1)),
      ], (t) => t);
      expect(_ids(sorted), [4, 3, 2, 1]);
    });

    test('prioridade vem antes do prazo', () {
      final sorted = sortTasks([
        _t(1, priority: TaskPriority.baixa, due: DateTime(2026, 11, 1)),
        _t(2, priority: TaskPriority.alta),
        _t(3, priority: TaskPriority.alta, due: DateTime(2026, 12, 1)),
      ], (t) => t);
      expect(_ids(sorted), [3, 2, 1]);
    });

    test('concluídas vão para o fim, mesmo com prioridade alta', () {
      final sorted = sortTasks([
        _t(1, priority: TaskPriority.alta, done: true),
        _t(2, priority: TaskPriority.baixa),
        _t(3, priority: TaskPriority.media, done: true),
      ], (t) => t);
      expect(_ids(sorted), [2, 1, 3]);
    });

    test('a hora do prazo é ignorada; empate desfeito pela criação', () {
      final sorted = sortTasks([
        _t(
          1,
          due: DateTime(2026, 11, 12, 23),
          created: DateTime(2026, 1, 3),
        ),
        _t(2, due: DateTime(2026, 11, 12, 1), created: DateTime(2026, 1, 2)),
      ], (t) => t);
      expect(_ids(sorted), [2, 1]);
    });

    test('não altera a lista original', () {
      final original = [
        _t(1, priority: TaskPriority.baixa),
        _t(2, priority: TaskPriority.alta),
      ];
      sortTasks(original, (t) => t);
      expect(_ids(original), [1, 2]);
    });
  });

  group('dueStatus', () {
    final today = DateTime(2026, 11, 11);
    test('classifica o prazo em relação a hoje', () {
      expect(dueStatus(null, today), DueStatus.none);
      expect(dueStatus(DateTime(2026, 11, 10), today), DueStatus.overdue);
      expect(dueStatus(DateTime(2026, 11, 11, 18), today), DueStatus.today);
      expect(dueStatus(DateTime(2026, 11, 12), today), DueStatus.upcoming);
    });
  });
}
