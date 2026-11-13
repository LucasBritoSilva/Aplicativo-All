import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/routine_repository.dart';
import '../data/routine_sync.dart';
import '../domain/routine_logic.dart';
import 'routine_widgets.dart';

/// Reorganizar: o usuário ajusta, à mão, os horários de um dia.
///
/// As mudanças ficam em rascunho, com os conflitos à vista, e só valem
/// depois de confirmadas. O app nunca reorganiza o dia por conta própria,
/// e o planejamento recorrente não é alterado: só as ocorrências do dia.
class ReorganizeScreen extends ConsumerStatefulWidget {
  const ReorganizeScreen({super.key, required this.day});

  final int day;

  @override
  ConsumerState<ReorganizeScreen> createState() => _ReorganizeScreenState();
}

class _ReorganizeScreenState extends ConsumerState<ReorganizeScreen> {
  /// Rascunho: id da ocorrência -> novo horário.
  final _changes = <int, ({int start, int end})>{};

  bool _movable(DayEntry e) =>
      e.kind == DayEntryKind.continuation ||
      (e.kind == DayEntryKind.normal &&
          e.view.occ.status == OccurrenceStatus.pending);

  bool _occupies(DayEntry e) =>
      e.kind == DayEntryKind.continuation ||
      (e.kind == DayEntryKind.normal &&
          (e.view.occ.status == OccurrenceStatus.pending ||
              e.view.occ.status == OccurrenceStatus.inProgress ||
              e.view.occ.status == OccurrenceStatus.paused));

  ({int start, int end}) _slot(DayEntry e) =>
      _changes[e.view.id] ?? (start: e.start, end: e.end);

  Future<void> _edit(DayEntry e) async {
    final occ = e.view.occ;
    if (occ.kind == ActivityKind.fixed) {
      final ok = await confirm(
        context,
        title: 'Compromisso fixo',
        message:
            '"${occ.name}" é um compromisso fixo. Deseja mesmo mudar o '
            'horário dele neste dia?',
        confirmLabel: 'Mudar',
      );
      if (!ok || !mounted) return;
    }
    final slot = _slot(e);
    final result = await showQuickForm(
      context,
      title: occ.name,
      submitLabel: 'Usar este horário',
      fields: [
        TimeSpec(
          'start',
          'Início',
          initial: slot.start % minutesPerDay,
          required: true,
        ),
        TimeSpec(
          'end',
          'Término (antes do início = dia seguinte)',
          initial: slot.end % minutesPerDay,
          required: true,
        ),
      ],
      validate: (v) => validateSpan(
        v.time('start')!,
        normalizeEnd(v.time('start')!, v.time('end')!),
      ),
    );
    if (result == null) return;
    final start = result.time('start')!;
    final next = (start: start, end: normalizeEnd(start, result.time('end')!));
    setState(() {
      if (next.start == e.start && next.end == e.end) {
        _changes.remove(e.view.id);
      } else {
        _changes[e.view.id] = next;
      }
    });
  }

  Future<void> _apply(List<DayEntry> entries, int conflictCount) async {
    final names = [
      for (final e in entries)
        if (_changes[e.view.id] case final slot?)
          '• ${e.view.occ.name}: ${formatSpan(e.start, e.end)}'
              ' → ${formatSpan(slot.start, slot.end)}',
    ];
    final ok = await confirm(
      context,
      title: 'Confirmar alterações',
      message:
          '${names.join('\n')}\n\n'
          '${conflictCount > 0 ? 'Atenção: ainda há conflito de horário neste dia.\n\n' : ''}'
          'Só as atividades deste dia mudam. As próximas repetições '
          'continuam como foram planejadas.',
      confirmLabel: 'Aplicar',
    );
    if (!ok || !mounted) return;
    final done = await runRoutineAction(
      context,
      () => ref
          .read(routineActionsProvider)
          .applyReorganization(widget.day, Map.of(_changes)),
    );
    if (done && mounted) {
      Navigator.pop(context);
      showMessage(context, 'Rotina do dia reorganizada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(routineDayProvider(widget.day));
    final date = dateFromEpochDay(widget.day);

    return Scaffold(
      appBar: AppBar(title: const Text('Reorganizar')),
      body: views.view((list) {
        final entries = buildDayEntries(
          list,
          widget.day,
        ).where(_occupies).toList();
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nada para reorganizar',
            message: 'Não há atividades em aberto neste dia.',
          );
        }
        final blocks = [
          for (final e in entries)
            TimeBlock(
              id: e.view.id,
              name: e.view.occ.name,
              kind: e.view.occ.kind,
              day: widget.day,
              start: _slot(e).start,
              end: _slot(e).end,
            ),
        ];
        final conflictsOf = {
          for (final e in entries)
            e.view.id: findConflicts(
              day: widget.day,
              start: _slot(e).start,
              end: _slot(e).end,
              blocks: blocks,
              ignoreId: e.view.id,
            ),
        };
        final conflictCount = conflictsOf.values
            .where((c) => c.isNotEmpty)
            .length;
        final sorted = [...entries]
          ..sort((a, b) => _slot(a).start.compareTo(_slot(b).start));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '${weekdayLong(date)}, ${formatDate(date)}. Toque em uma '
                'atividade para escolher outro horário. Nada muda até você '
                'confirmar.',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = sorted[i];
                  final slot = _slot(e);
                  final changed = _changes.containsKey(e.view.id);
                  final conflicts = conflictsOf[e.view.id]!;
                  final movable = _movable(e);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: movable ? () => _edit(e) : null,
                      leading: Icon(
                        kindIcon(e.view.occ.kind),
                        color: e.view.occ.kind == ActivityKind.fixed
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      title: Text(
                        e.kind == DayEntryKind.continuation
                            ? 'Retomada: ${e.view.occ.name}'
                            : e.view.occ.name,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            changed
                                ? '${formatSpan(e.start, e.end)}'
                                      ' → ${formatSpan(slot.start, slot.end)}'
                                : formatSpan(slot.start, slot.end),
                            style: TextStyle(
                              color: changed
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                          if (!movable)
                            const Text(
                              'Em andamento: não pode ser movida agora',
                              style: TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 12,
                              ),
                            ),
                          if (conflicts.isNotEmpty)
                            Text(
                              'Conflito com: '
                              '${conflicts.map(describeConflict).join('; ')}',
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: changed
                          ? IconButton(
                              tooltip: 'Desfazer esta mudança',
                              icon: const Icon(Icons.undo),
                              onPressed: () =>
                                  setState(() => _changes.remove(e.view.id)),
                            )
                          : (movable ? const Icon(Icons.edit_outlined) : null),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _changes.isEmpty
                            ? null
                            : () => setState(_changes.clear),
                        child: const Text('Descartar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _changes.isEmpty
                            ? null
                            : () => _apply(entries, conflictCount),
                        child: Text(
                          _changes.isEmpty
                              ? 'Confirmar alterações'
                              : 'Confirmar (${_changes.length})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
