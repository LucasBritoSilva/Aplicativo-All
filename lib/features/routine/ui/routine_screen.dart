import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../data/routine_repository.dart';
import '../domain/routine_logic.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final items = ref.watch(routineItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rotina')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar item da rotina',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.wb_sunny_outlined,
              title: 'Nenhum item na rotina',
              message:
                  'Adicione o que você faz todo dia. As marcações '
                  'são zeradas automaticamente no dia seguinte.',
            );
          }
          final done = list
              .where((i) => isDoneToday(doneOn: i.doneOn, today: today))
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${weekdayLong(today)}, ${formatDayMonth(today)}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done == list.length
                            ? 'Rotina completa hoje'
                            : '$done de ${list.length} feitos hoje',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ProgressBar(value: done / list.length),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    for (final item in list)
                      _RoutineTile(
                        item: item,
                        done: isDoneToday(doneOn: item.doneOn, today: today),
                        onToggle: (value) => ref
                            .read(routineRepositoryProvider)
                            .setDone(item.id, done: value, today: today),
                        onEdit: () => _openForm(context, item: item),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, {RoutineItem? item}) {
    showFormSheet<void>(
      context,
      title: item == null ? 'Novo item da rotina' : 'Editar item',
      builder: (_) => _RoutineForm(item: item),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.item,
    required this.done,
    required this.onToggle,
    required this.onEdit,
  });

  final RoutineItem item;
  final bool done;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => onToggle(!done),
      leading: Checkbox(value: done, onChanged: (v) => onToggle(v ?? false)),
      title: Text(
        item.title,
        style: done
            ? const TextStyle(
                color: AppColors.textFaint,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      trailing: IconButton(
        tooltip: 'Editar',
        icon: const Icon(Icons.edit_outlined, size: 20),
        onPressed: onEdit,
      ),
    );
  }
}

class _RoutineForm extends ConsumerStatefulWidget {
  const _RoutineForm({this.item});
  final RoutineItem? item;

  @override
  ConsumerState<_RoutineForm> createState() => _RoutineFormState();
}

class _RoutineFormState extends ConsumerState<_RoutineForm> {
  late final _title = TextEditingController(text: widget.item?.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Digite o item da rotina.');
      return;
    }
    final repo = ref.read(routineRepositoryProvider);
    if (widget.item == null) {
      await repo.add(title);
    } else {
      await repo.rename(widget.item!.id, title);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(routineRepositoryProvider).delete(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex.: beber 2 litros de água',
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.item != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir item'),
          ),
        ],
      ],
    );
  }
}
