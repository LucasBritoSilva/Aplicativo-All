import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../data/goals_repository.dart';
import '../domain/goal_progress.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova meta',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: goals.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Nenhuma meta',
              message:
                  'Crie uma meta de longo prazo, como "ler 20 livros" '
                  'ou "guardar 5000 reais".',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _GoalCard(
              goal: list[i],
              today: today,
              onEdit: () => _openForm(context, goal: list[i]),
              onUpdate: () => _updateValue(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, {Goal? goal}) {
    showFormSheet<void>(
      context,
      title: goal == null ? 'Nova meta' : 'Editar meta',
      builder: (_) => _GoalForm(goal: goal),
    );
  }

  Future<void> _updateValue(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _UpdateValueDialog(goal: goal),
    );
    if (value != null) {
      await ref.read(goalsRepositoryProvider).setCurrent(goal.id, value);
    }
  }
}

class _UpdateValueDialog extends StatefulWidget {
  const _UpdateValueDialog({required this.goal});
  final Goal goal;

  @override
  State<_UpdateValueDialog> createState() => _UpdateValueDialogState();
}

class _UpdateValueDialogState extends State<_UpdateValueDialog> {
  late final _controller = TextEditingController(
    text: formatNumber(widget.goal.currentValue),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atualizar progresso'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(
          labelText: 'Valor atual',
          suffixText: widget.goal.unit,
          helperText: 'Meta: ${formatNumber(widget.goal.targetValue)}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, parseNumber(_controller.text)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.today,
    required this.onEdit,
    required this.onUpdate,
  });

  final Goal goal;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final fraction = goalProgress(
      current: goal.currentValue,
      target: goal.targetValue,
    );
    final percent = goalPercent(
      current: goal.currentValue,
      target: goal.targetValue,
    );
    final reached = goalReached(
      current: goal.currentValue,
      target: goal.targetValue,
    );
    final unit = goal.unit == null ? '' : ' ${goal.unit}';
    final days = daysUntilDeadline(deadline: goal.deadline, today: today);
    String? deadlineText;
    if (goal.deadline != null) {
      final date = formatDate(goal.deadline!);
      if (reached) {
        deadlineText = 'Prazo: $date';
      } else if (days! > 1) {
        deadlineText = 'Até $date · faltam $days dias';
      } else if (days == 1) {
        deadlineText = 'Até $date · falta 1 dia';
      } else if (days == 0) {
        deadlineText = 'Prazo termina hoje';
      } else {
        deadlineText = 'Prazo vencido em $date';
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: reached ? AppColors.primary : AppColors.text,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar progresso',
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    onPressed: onUpdate,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ProgressBar(value: fraction, height: 8),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatNumber(goal.currentValue)} de '
                '${formatNumber(goal.targetValue)}$unit'
                '${reached ? ' · meta alcançada' : ''}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (deadlineText != null) ...[
                const SizedBox(height: 4),
                Text(
                  deadlineText,
                  style: TextStyle(
                    fontSize: 13,
                    color: (days ?? 0) < 0 && !reached
                        ? AppColors.danger
                        : AppColors.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.goal});
  final Goal? goal;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _title = TextEditingController(text: widget.goal?.title);
  late final _current = TextEditingController(
    text: widget.goal == null ? '0' : formatNumber(widget.goal!.currentValue),
  );
  late final _target = TextEditingController(
    text: widget.goal == null ? '' : formatNumber(widget.goal!.targetValue),
  );
  late final _unit = TextEditingController(text: widget.goal?.unit);
  late DateTime? _deadline = widget.goal?.deadline;

  @override
  void dispose() {
    _title.dispose();
    _current.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final current = parseNumber(_current.text) ?? 0;
    final target = parseNumber(_target.text);
    if (title.isEmpty) {
      showMessage(context, 'Digite o nome da meta.');
      return;
    }
    if (target == null || target <= 0) {
      showMessage(context, 'O valor-alvo precisa ser maior que zero.');
      return;
    }
    final unit = _unit.text.trim();
    await ref
        .read(goalsRepositoryProvider)
        .save(
          id: widget.goal?.id,
          title: title,
          current: current,
          target: target,
          unit: unit.isEmpty ? null : unit,
          deadline: _deadline,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir meta',
      message: 'Excluir "${widget.goal!.title}"?',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(goalsRepositoryProvider).delete(widget.goal!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final numberInput = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.goal == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex.: ler 20 livros'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _current,
                keyboardType: numberKeyboard,
                inputFormatters: numberInput,
                decoration: const InputDecoration(labelText: 'Valor atual'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _target,
                keyboardType: numberKeyboard,
                inputFormatters: numberInput,
                decoration: const InputDecoration(labelText: 'Valor-alvo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _unit,
          decoration: const InputDecoration(
            hintText: 'Unidade (opcional, ex.: livros, km, R\$)',
          ),
        ),
        const SizedBox(height: 12),
        PickerField(
          icon: Icons.event_outlined,
          label: _deadline == null
              ? 'Sem data-limite'
              : 'Até ${formatDate(_deadline!)}',
          onTap: () async {
            final d = await pickDate(context, initial: _deadline);
            if (d != null) setState(() => _deadline = dateOnly(d));
          },
          onClear: _deadline == null
              ? null
              : () => setState(() => _deadline = null),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.goal != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir meta'),
          ),
        ],
      ],
    );
  }
}
