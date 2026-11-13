import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/text.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/tasks_repository.dart';
import '../domain/task_sorting.dart';

Color priorityColor(TaskPriority p) => switch (p) {
  TaskPriority.alta => AppColors.primary,
  TaskPriority.media => AppColors.textMuted,
  TaskPriority.baixa => AppColors.textFaint,
};

IconData priorityIcon(TaskPriority p) => switch (p) {
  TaskPriority.alta => Icons.keyboard_double_arrow_up,
  TaskPriority.media => Icons.drag_handle,
  TaskPriority.baixa => Icons.keyboard_arrow_down,
};

enum TaskFilter {
  pending('Pendentes'),
  done('Concluídas'),
  all('Todas');

  const TaskFilter(this.label);
  final String label;
}

/// Filtra as tarefas pela situação e pela busca.
List<TaskWithSubtasks> filterTasks(
  List<TaskWithSubtasks> list,
  TaskFilter filter,
  String query,
) => [
  for (final t in list)
    if ((filter == TaskFilter.all ||
            (filter == TaskFilter.done) == t.task.done) &&
        matchesQuery(query, [
          t.task.title,
          t.task.notes,
          ...t.subtasks.map((s) => s.title),
        ]))
      t,
];

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.pending;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final tasks = ref.watch(sortedTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas'),
        actions: [
          if (_filter == TaskFilter.done)
            IconButton(
              tooltip: 'Excluir concluídas',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clearDone(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova tarefa',
        onPressed: () => openTaskForm(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar tarefas',
            onChanged: (v) => setState(() => _query = v),
          ),
          FilterBar<TaskFilter>(
            options: [for (final f in TaskFilter.values) (f, f.label)],
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: tasks.view((all) {
              final list = filterTasks(all, _filter, _query);
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.check_circle_outline,
                  title: all.isEmpty
                      ? 'Nenhuma tarefa'
                      : _filter == TaskFilter.pending && _query.isEmpty
                      ? 'Tudo em dia'
                      : 'Nada encontrado',
                  message: all.isEmpty
                      ? 'Toque em + para criar uma tarefa com prioridade, '
                            'prazo e subtarefas.'
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _TaskCard(item: list[i], today: today),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDone(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Excluir concluídas',
      message: 'Excluir de vez todas as tarefas concluídas?',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await ref.read(tasksRepositoryProvider).clearDone();
  }
}

void openTaskForm(BuildContext context, {TaskWithSubtasks? item}) {
  showFormSheet<void>(
    context,
    title: item == null ? 'Nova tarefa' : 'Editar tarefa',
    builder: (_) => _TaskForm(item: item),
  );
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.item, required this.today});

  final TaskWithSubtasks item;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = item.task;
    final repo = ref.read(tasksRepositoryProvider);
    final status = dueStatus(task.dueDate, today);
    final pills = <Widget>[
      Pill(
        task.priority.label,
        color: priorityColor(task.priority),
        icon: priorityIcon(task.priority),
      ),
      if (task.dueDate != null)
        Pill(
          status == DueStatus.overdue && !task.done
              ? 'Atrasada · ${formatDayMonth(task.dueDate!)}'
              : friendlyDay(task.dueDate!, today),
          icon: Icons.event_outlined,
          color: task.done
              ? AppColors.textFaint
              : switch (status) {
                  DueStatus.overdue => AppColors.danger,
                  DueStatus.today => AppColors.primary,
                  _ => AppColors.textMuted,
                },
        ),
      if (item.subtasks.isNotEmpty)
        Pill(
          '${item.subtasksDone}/${item.subtasks.length}',
          icon: Icons.checklist,
        ),
      if (task.done && task.completedAt != null)
        Pill(
          'Concluída ${friendlyDay(task.completedAt!, today).toLowerCase()}',
          color: AppColors.success,
        ),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openTaskForm(context, item: item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: task.done,
                    onChanged: (v) => repo.setDone(task.id, v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: task.done
                                ? const TextStyle(
                                    color: AppColors.textFaint,
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : const TextStyle(fontSize: 16),
                          ),
                          if (task.notes != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              task.notes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 4, children: pills),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!task.done && item.subtasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 4),
                  child: Column(
                    children: [
                      for (final s in item.subtasks)
                        InkWell(
                          onTap: () => repo.setSubtaskDone(s.id, !s.done),
                          child: Row(
                            children: [
                              Icon(
                                s.done
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 20,
                                color: s.done
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    s.title,
                                    style: TextStyle(
                                      color: s.done
                                          ? AppColors.textFaint
                                          : AppColors.text,
                                      decoration: s.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.item});
  final TaskWithSubtasks? item;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  TaskItem? get _task => widget.item?.task;
  late final _title = TextEditingController(text: _task?.title);
  late final _notes = TextEditingController(text: _task?.notes);
  final _newSubtask = TextEditingController();
  late TaskPriority _priority = _task?.priority ?? TaskPriority.media;
  late DateTime? _due = _task?.dueDate;
  late final List<SubtaskDraft> _subtasks = [
    for (final s in widget.item?.subtasks ?? const <TaskSubtask>[])
      (id: s.id, title: s.title, done: s.done),
  ];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _newSubtask.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final t = _newSubtask.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _subtasks.add((id: null, title: t, done: false));
      _newSubtask.clear();
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Digite a tarefa.');
      return;
    }
    _addSubtask();
    final notes = _notes.text.trim();
    await ref
        .read(tasksRepositoryProvider)
        .save(
          id: _task?.id,
          title: title,
          notes: notes.isEmpty ? null : notes,
          priority: _priority,
          dueDate: _due,
          subtasks: _subtasks,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir tarefa',
      message: 'A tarefa e as subtarefas serão apagadas.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(tasksRepositoryProvider).delete(_task!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: task == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
        ),
        const SizedBox(height: 16),
        const Text('Prioridade', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        SegmentedButton<TaskPriority>(
          showSelectedIcon: false,
          segments: [
            for (final p in TaskPriority.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {_priority},
          onSelectionChanged: (s) => setState(() => _priority = s.first),
        ),
        const SizedBox(height: 16),
        PickerField(
          icon: Icons.event_outlined,
          label: _due == null
              ? 'Sem prazo'
              : 'Prazo: ${weekdayShort(_due!)}, ${formatDate(_due!)}',
          onTap: () async {
            final d = await pickDate(context, initial: _due);
            if (d != null) setState(() => _due = dateOnly(d));
          },
          onClear: _due == null ? null : () => setState(() => _due = null),
        ),
        const SizedBox(height: 16),
        const Text('Subtarefas', style: TextStyle(color: AppColors.textMuted)),
        for (final (i, s) in _subtasks.indexed)
          Row(
            children: [
              Checkbox(
                value: s.done,
                onChanged: (v) => setState(
                  () => _subtasks[i] = (
                    id: s.id,
                    title: s.title,
                    done: v ?? false,
                  ),
                ),
              ),
              Expanded(child: Text(s.title)),
              IconButton(
                tooltip: 'Remover subtarefa',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _subtasks.removeAt(i)),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newSubtask,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _addSubtask(),
                decoration: const InputDecoration(
                  hintText: 'Nova subtarefa',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Adicionar subtarefa',
              icon: const Icon(Icons.add),
              onPressed: _addSubtask,
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (task != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await ref
                  .read(tasksRepositoryProvider)
                  .setDone(task.id, !task.done);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(task.done ? 'Reabrir tarefa' : 'Concluir tarefa'),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir tarefa'),
          ),
        ],
      ],
    );
  }
}
