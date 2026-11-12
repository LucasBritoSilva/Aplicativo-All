import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../data/habits_repository.dart';
import '../domain/habit_progress.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final weekStart = startOfWeek(today);
    final habits = ref.watch(habitsProvider);
    final checks = ref.watch(weekChecksProvider(weekStart));

    return Scaffold(
      appBar: AppBar(title: const Text('Hábitos')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo hábito',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: habits.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.repeat,
              title: 'Nenhum hábito',
              message:
                  'Crie um hábito com meta semanal, como '
                  '"correr 3 vezes por semana".',
            );
          }
          final allChecks = checks.maybeWhen(
            data: (c) => c,
            orElse: () => const <HabitCheck>[],
          );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    'Semana de ${formatWeekRange(today)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              final habit = list[i - 1];
              final days = allChecks
                  .where((c) => c.habitId == habit.id)
                  .map((c) => c.day)
                  .toList();
              return _HabitCard(
                habit: habit,
                checkedDays: days,
                today: today,
                onEdit: () => _openForm(context, habit: habit),
              );
            },
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, {Habit? habit}) {
    showFormSheet<void>(
      context,
      title: habit == null ? 'Novo hábito' : 'Editar hábito',
      builder: (_) => _HabitForm(habit: habit),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({
    required this.habit,
    required this.checkedDays,
    required this.today,
    required this.onEdit,
  });

  final Habit habit;
  final List<DateTime> checkedDays;
  final DateTime today;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = habitWeekProgress(
      checks: checkedDays,
      weeklyTarget: habit.weeklyTarget,
      today: today,
    );
    final status = progress.achieved
        ? 'Meta da semana cumprida (${progress.done}/${progress.target})'
        : '${progress.done} de ${progress.target} nesta semana';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        habit.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Meta: ${habit.weeklyTarget}x por semana',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final day in daysOfWeek(today))
                    _DayDot(
                      day: day,
                      checked: checkedDays.any((d) => isSameDay(d, day)),
                      isToday: isSameDay(day, today),
                      enabled: !day.isAfter(today),
                      onTap: () => ref
                          .read(habitsRepositoryProvider)
                          .toggle(habit.id, day),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ProgressBar(value: progress.fraction),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 13,
                color: progress.achieved
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.checked,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool checked;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = checked ? AppColors.primary : Colors.transparent;
    final border = checked
        ? AppColors.primary
        : isToday
        ? AppColors.textMuted
        : AppColors.outline;
    return Column(
      children: [
        Text(
          weekdayLetter(day),
          style: TextStyle(
            fontSize: 11,
            color: isToday ? AppColors.text : AppColors.textFaint,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          button: true,
          checked: checked,
          label: '${weekdayLong(day)} ${day.day}',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 1.5),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 18, color: AppColors.onPrimary)
                  : Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? AppColors.text : AppColors.textFaint,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitForm extends ConsumerStatefulWidget {
  const _HabitForm({this.habit});
  final Habit? habit;

  @override
  ConsumerState<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<_HabitForm> {
  late final _name = TextEditingController(text: widget.habit?.name);
  late int _target = widget.habit?.weeklyTarget ?? 3;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Digite o nome do hábito.');
      return;
    }
    await ref
        .read(habitsRepositoryProvider)
        .save(id: widget.habit?.id, name: name, target: _target);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir hábito',
      message: 'Excluir "${widget.habit!.name}" e todo o histórico dele?',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(habitsRepositoryProvider).delete(widget.habit!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: widget.habit == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex.: correr'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Menos',
                icon: const Icon(Icons.remove),
                onPressed: _target > 1
                    ? () => setState(() => _target--)
                    : null,
              ),
              Expanded(
                child: Text(
                  '$_target ${_target == 1 ? 'vez' : 'vezes'} por semana',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mais',
                icon: const Icon(Icons.add),
                onPressed: _target < 7
                    ? () => setState(() => _target++)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.habit != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir hábito'),
          ),
        ],
      ],
    );
  }
}
