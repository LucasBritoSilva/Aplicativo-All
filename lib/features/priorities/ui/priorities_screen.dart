import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/priorities_repository.dart';

/// Até três prioridades por dia. Cada dia começa com uma lista nova e os
/// dias anteriores ficam no histórico.
class PrioritiesScreen extends ConsumerWidget {
  const PrioritiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayDate = ref.watch(todayProvider);
    final today = epochDay(todayDate);
    final items = ref.watch(prioritiesOfDayProvider(today));
    final yesterday = ref.watch(prioritiesOfDayProvider(today - 1));
    final repo = ref.read(prioritiesRepositoryProvider);

    Future<void> add() async {
      final r = await showQuickForm(
        context,
        title: 'Nova prioridade',
        fields: const [
          TextSpec('title', 'Prioridade', required: true, autofocus: true),
        ],
      );
      if (r == null) return;
      try {
        await repo.add(today, r.text('title'));
      } on PrioritiesFullError catch (e) {
        if (context.mounted) showMessage(context, e.toString());
      }
    }

    Future<void> edit(DailyPriority p) async {
      final r = await showQuickForm(
        context,
        title: 'Editar prioridade',
        deleteLabel: 'Excluir prioridade',
        fields: [
          TextSpec('title', 'Prioridade', initial: p.title, required: true),
        ],
      );
      if (r == null) return;
      if (r.deleted) {
        await repo.delete(p.id);
      } else {
        await repo.rename(p.id, r.text('title'));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prioridades do dia'),
        actions: [
          IconButton(
            tooltip: 'Dias anteriores',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _PrioritiesHistoryScreen(today: today),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (items.value?.length ?? 0) < maxDailyPriorities
          ? FloatingActionButton(
              tooltip: 'Nova prioridade',
              onPressed: add,
              child: const Icon(Icons.add),
            )
          : null,
      body: items.view((list) {
        final done = list.where((p) => p.done).length;
        final pendingYesterday =
            yesterday.value?.where((p) => !p.done).length ?? 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '${weekdayLong(todayDate)}, ${formatLongDate(todayDate)}'
                '${list.isEmpty ? '' : ' · $done de ${list.length} concluídas'}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            if (list.isEmpty)
              const EmptyState(
                icon: Icons.flag_outlined,
                title: 'Nenhuma prioridade hoje',
                message:
                    'Escolha até três coisas que mais importam hoje. Amanhã '
                    'começa uma lista nova.',
              )
            else
              Card(
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) => repo.reorder(
                    reorderIds([for (final p in list) p.id], from, to),
                  ),
                  children: [
                    for (final (i, p) in list.indexed)
                      ListTile(
                        key: ValueKey(p.id),
                        onTap: () => edit(p),
                        leading: Checkbox(
                          value: p.done,
                          onChanged: (v) => repo.setDone(p.id, v ?? false),
                        ),
                        title: Text(
                          '${i + 1}. ${p.title}',
                          style: p.done
                              ? const TextStyle(
                                  color: AppColors.textFaint,
                                  decoration: TextDecoration.lineThrough,
                                )
                              : const TextStyle(fontSize: 17),
                        ),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (pendingYesterday > 0 && list.length < maxDailyPriorities) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final n = await repo.carryOver(today - 1, today);
                  if (context.mounted) {
                    showMessage(
                      context,
                      n == 0
                          ? 'Nada para trazer de ontem.'
                          : 'Trazidas $n prioridades de ontem.',
                    );
                  }
                },
                icon: const Icon(Icons.redo),
                label: Text('Trazer as pendentes de ontem ($pendingYesterday)'),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _PrioritiesHistoryScreen extends ConsumerWidget {
  const _PrioritiesHistoryScreen({required this.today});

  final int today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(prioritiesHistoryProvider(today));
    final todayDate = dateFromEpochDay(today);
    return Scaffold(
      appBar: AppBar(title: const Text('Dias anteriores')),
      body: history.view((list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'Sem histórico ainda',
          );
        }
        final byDay = <int, List<DailyPriority>>{};
        for (final p in list) {
          (byDay[p.day] ??= []).add(p);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            for (final entry in byDay.entries) ...[
              SectionLabel(
                friendlyDay(dateFromEpochDay(entry.key), todayDate),
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                trailing: Text(
                  '${entry.value.where((p) => p.done).length}/${entry.value.length}',
                  style: const TextStyle(color: AppColors.textFaint),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final p in entry.value)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          p.done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: p.done
                              ? AppColors.success
                              : AppColors.textFaint,
                        ),
                        title: Text(p.title),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
