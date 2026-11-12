import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
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

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final tasks = ref.watch(sortedTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tarefas')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova tarefa',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: tasks.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nenhuma tarefa',
              message: 'Toque em + para criar uma tarefa com prioridade e prazo.',
            );
          }
          final pending = list.where((t) => !t.done).toList();
          final done = list.where((t) => t.done).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Tudo em dia. Nenhuma tarefa pendente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final t in pending)
                        _TaskTile(
                          task: t,
                          today: today,
                          onEdit: () => _openForm(context, task: t),
                        ),
                    ],
                  ),
                ),
              if (done.isNotEmpty) ...[
                SectionLabel(
                  'Concluídas (${done.length})',
                  padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showDone)
                        TextButton(
                          onPressed: () => _clearDone(context),
                          child: const Text('Limpar'),
                        ),
                      IconButton(
                        tooltip: _showDone ? 'Esconder' : 'Mostrar',
                        icon: Icon(
                          _showDone ? Icons.expand_less : Icons.expand_more,
                        ),
                        onPressed: () => setState(() => _showDone = !_showDone),
                      ),
                    ],
                  ),
                ),
                if (_showDone)
                  Card(
                    child: Column(
                      children: [
                        for (final t in done)
                          _TaskTile(
                            task: t,
                            today: today,
                            onEdit: () => _openForm(context, task: t),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _clearDone(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Limpar concluídas',
      message: 'Excluir todas as tarefas concluídas?',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await ref.read(tasksRepositoryProvider).clearDone();
  }

  void _openForm(BuildContext context, {TaskItem? task}) {
    showFormSheet<void>(
      context,
      title: task == null ? 'Nova tarefa' : 'Editar tarefa',
      builder: (_) => _TaskForm(task: task),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    required this.today,
    required this.onEdit,
  });

  final TaskItem task;
  final DateTime today;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    ];
    return ListTile(
      onTap: onEdit,
      leading: Checkbox(
        value: task.done,
        onChanged: (v) =>
            ref.read(tasksRepositoryProvider).setDone(task.id, v ?? false),
      ),
      title: Text(
        task.title,
        style: task.done
            ? const TextStyle(
                color: AppColors.textFaint,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(spacing: 6, runSpacing: 4, children: pills),
      ),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.task});
  final TaskItem? task;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.media;
  late DateTime? _due = widget.task?.dueDate;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Digite a tarefa.');
      return;
    }
    final notes = _notes.text.trim();
    await ref
        .read(tasksRepositoryProvider)
        .save(
          id: widget.task?.id,
          title: title,
          notes: notes.isEmpty ? null : notes,
          priority: _priority,
          dueDate: _due,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(tasksRepositoryProvider).delete(widget.task!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.task == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'O que precisa ser feito?'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Detalhes (opcional)'),
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
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.task != null) ...[
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
