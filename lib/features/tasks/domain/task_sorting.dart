import '../../../core/utils/dates.dart';

/// Prioridade de uma tarefa. A ordem da lista é a ordem de importância.
enum TaskPriority {
  alta('Alta'),
  media('Média'),
  baixa('Baixa');

  const TaskPriority(this.label);
  final String label;
}

/// Campos usados para ordenar tarefas.
class TaskOrderKey {
  const TaskOrderKey({
    required this.id,
    required this.done,
    required this.priority,
    this.dueDate,
    required this.createdAt,
  });

  final int id;
  final bool done;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime createdAt;
}

/// Ordem das tarefas:
/// 1. pendentes antes das concluídas;
/// 2. prioridade (alta, média, baixa);
/// 3. prazo mais próximo primeiro (sem prazo vai para o fim);
/// 4. criadas antes primeiro; por último, o id (ordem estável).
int compareTasks(TaskOrderKey a, TaskOrderKey b) {
  if (a.done != b.done) return a.done ? 1 : -1;

  final byPriority = a.priority.index.compareTo(b.priority.index);
  if (byPriority != 0) return byPriority;

  final aDue = a.dueDate == null ? null : dateOnly(a.dueDate!);
  final bDue = b.dueDate == null ? null : dateOnly(b.dueDate!);
  if (aDue != null && bDue == null) return -1;
  if (aDue == null && bDue != null) return 1;
  if (aDue != null && bDue != null) {
    final byDue = aDue.compareTo(bDue);
    if (byDue != 0) return byDue;
  }

  final byCreated = a.createdAt.compareTo(b.createdAt);
  if (byCreated != 0) return byCreated;
  return a.id.compareTo(b.id);
}

/// Devolve uma nova lista ordenada, sem alterar a original.
List<T> sortTasks<T>(Iterable<T> tasks, TaskOrderKey Function(T) keyOf) {
  final list = tasks.toList();
  list.sort((a, b) => compareTasks(keyOf(a), keyOf(b)));
  return list;
}

/// Situação do prazo em relação a hoje.
enum DueStatus { none, overdue, today, upcoming }

DueStatus dueStatus(DateTime? dueDate, DateTime today) {
  if (dueDate == null) return DueStatus.none;
  final diff = daysBetween(today, dueDate);
  if (diff < 0) return DueStatus.overdue;
  if (diff == 0) return DueStatus.today;
  return DueStatus.upcoming;
}
