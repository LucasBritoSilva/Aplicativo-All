import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/gym_repository.dart';
import '../domain/gym_logic.dart';

/// Academia: fichas de treino e acompanhamento do peso corporal.
class GymScreen extends StatelessWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Academia'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.fitness_center), text: 'Fichas'),
              Tab(
                icon: Icon(Icons.monitor_weight_outlined),
                text: 'Peso corporal',
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [_SheetsTab(), _WeightTab()]),
      ),
    );
  }
}

class _SheetsTab extends ConsumerWidget {
  const _SheetsTab();

  Future<void> _sheetForm(
    BuildContext context,
    WidgetRef ref,
    List<SheetView> all, [
    WorkoutSheet? s,
  ]) async {
    final r = await showQuickForm(
      context,
      title: s == null ? 'Nova ficha' : 'Renomear ficha',
      deleteLabel: s == null ? null : 'Excluir ficha',
      fields: [
        TextSpec(
          'name',
          'Nome da ficha',
          initial: s?.name ?? nextSheetName(all.map((v) => v.sheet.name)),
          required: true,
        ),
      ],
    );
    if (r == null || !context.mounted) return;
    final repo = ref.read(gymRepositoryProvider);
    if (r.deleted) {
      final ok = await confirm(
        context,
        title: 'Excluir ficha',
        message: '"${s!.name}" e todos os exercícios dela serão apagados.',
        confirmLabel: 'Excluir',
        destructive: true,
      );
      if (ok) await repo.deleteSheet(s.id);
      return;
    }
    await repo.saveSheet(id: s?.id, name: r.text('name'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheets = ref.watch(sheetsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _sheetForm(context, ref, sheets.value ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('Ficha'),
      ),
      body: sheets.view((list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.fitness_center,
            title: 'Nenhuma ficha de treino',
            message:
                'Crie fichas como Treino A, B, C... e cadastre os '
                'exercícios com séries, repetições e carga.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            for (final v in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      v.sheet.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      v.exercises.isEmpty
                          ? 'Sem exercícios'
                          : '${v.exercises.length} exercício${v.exercises.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    children: [
                      for (final e in v.exercises)
                        ListTile(
                          onTap: () =>
                              openExerciseForm(context, ref, v.sheet.id, e),
                          title: Text(e.name),
                          subtitle: Text(
                            describeExercise(
                                  sets: e.sets,
                                  reps: e.reps,
                                  load: e.load,
                                ) +
                                (e.notes == null ? '' : '\n${e.notes}'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          trailing: IconButton(
                            tooltip: 'Histórico de carga',
                            icon: const Icon(Icons.show_chart),
                            onPressed: () => showLoadHistory(context, e),
                          ),
                        ),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _sheetForm(context, ref, list, v.sheet),
                            child: const Text('Editar ficha'),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                openExerciseForm(context, ref, v.sheet.id),
                            icon: const Icon(Icons.add),
                            label: const Text('Exercício'),
                          ),
                        ],
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

Future<void> openExerciseForm(
  BuildContext context,
  WidgetRef ref,
  int sheetId, [
  WorkoutExercise? e,
]) async {
  final r = await showQuickForm(
    context,
    title: e == null ? 'Novo exercício' : 'Editar exercício',
    deleteLabel: e == null ? null : 'Excluir exercício',
    fields: [
      TextSpec(
        'name',
        'Exercício',
        initial: e?.name,
        required: true,
        autofocus: e == null,
      ),
      NumberSpec(
        'sets',
        'Séries',
        initial: e?.sets.toDouble() ?? 3,
        required: true,
        decimal: false,
        min: 1,
        max: 100,
      ),
      TextSpec(
        'reps',
        'Repetições (ex.: 12 ou 8-10)',
        initial: e?.reps ?? '12',
        required: true,
        capitalization: TextCapitalization.none,
      ),
      NumberSpec(
        'load',
        'Carga (kg, opcional)',
        initial: e?.load,
        min: 0,
        suffix: 'kg',
      ),
      TextSpec('notes', 'Observações', initial: e?.notes, lines: 2),
    ],
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(gymRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir exercício',
      message: '"${e!.name}" e o histórico de carga serão apagados.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteExercise(e.id);
    return;
  }
  await repo.saveExercise(
    id: e?.id,
    sheetId: sheetId,
    name: r.text('name'),
    sets: r.integer('sets')!,
    reps: r.text('reps'),
    load: r.number('load'),
    notes: r.textOrNull('notes'),
    today: epochDay(DateTime.now()),
  );
}

void showLoadHistory(BuildContext context, WorkoutExercise e) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final history = ref.watch(loadHistoryProvider(e.id));
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: history.view(
            (list) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Carga: ${e.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  const Text(
                    'Sem histórico. A carga é registrada quando você a altera.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else ...[
                  if (list.length > 1)
                    SimpleLineChart(
                      values: [for (final l in list) l.load],
                      format: (v) =>
                          formatNumber(double.parse(v.toStringAsFixed(1))),
                      startLabel: formatDayMonthNumeric(
                        dateFromEpochDay(list.first.day),
                      ),
                      endLabel: formatDayMonthNumeric(
                        dateFromEpochDay(list.last.day),
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (final l in list.reversed.take(8))
                    Text(
                      '${formatDate(dateFromEpochDay(l.day))}: ${formatNumber(l.load)} kg',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _WeightTab extends ConsumerWidget {
  const _WeightTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weights = ref.watch(weightsProvider);
    final goal = ref.watch(weightGoalProvider);
    final today = epochDay(ref.watch(todayProvider));
    final repo = ref.read(gymRepositoryProvider);

    Future<void> log() async {
      final last = weights.value?.lastOrNull;
      final r = await showQuickForm(
        context,
        title: 'Registrar peso',
        fields: [
          NumberSpec(
            'w',
            'Peso',
            initial: last?.weight,
            required: true,
            min: 1,
            max: 500,
            suffix: 'kg',
          ),
          DateSpec('day', 'Data', initial: DateTime.now(), required: true),
        ],
      );
      if (r == null) return;
      await repo.logWeight(epochDay(r.date('day')!), r.number('w')!);
    }

    Future<void> setGoal() async {
      final r = await showQuickForm(
        context,
        title: 'Meta de peso',
        fields: [
          NumberSpec(
            'g',
            'Meta (vazio para remover)',
            initial: goal,
            min: 1,
            max: 500,
            suffix: 'kg',
          ),
        ],
      );
      if (r == null) return;
      await repo.setGoal(r.number('g'));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: log,
        icon: const Icon(Icons.add),
        label: const Text('Peso'),
      ),
      body: weights.view((list) {
        final current = list.lastOrNull?.weight;
        final gap = weightGap(current, goal);
        final change = weightChange([for (final w in list) w.weight]);
        final recent = list.length > 30 ? list.sublist(list.length - 30) : list;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            StatRow(
              tiles: [
                StatTile(
                  value: current == null ? '—' : '${formatNumber(current)} kg',
                  label: 'Atual',
                ),
                StatTile(
                  value: goal == null ? '—' : '${formatNumber(goal)} kg',
                  label: 'Meta',
                ),
                StatTile(
                  value: change == null
                      ? '—'
                      : '${change > 0 ? '+' : ''}${formatNumber(double.parse(change.toStringAsFixed(1)))} kg',
                  label: 'Desde o 1º registro',
                ),
              ],
            ),
            if (gap != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  gap.label,
                  style: TextStyle(
                    color: gap.reached ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: setGoal,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  goal == null ? 'Definir meta de peso' : 'Alterar meta',
                ),
              ),
            ),
            if (list.length >= 2) ...[
              const SectionLabel(
                'Evolução',
                padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SimpleLineChart(
                    values: [for (final w in recent) w.weight],
                    goal: goal,
                    format: (v) =>
                        formatNumber(double.parse(v.toStringAsFixed(1))),
                    startLabel: formatDayMonthNumeric(
                      dateFromEpochDay(recent.first.day),
                    ),
                    endLabel: formatDayMonthNumeric(
                      dateFromEpochDay(recent.last.day),
                    ),
                  ),
                ),
              ),
              if (goal != null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    'Linha tracejada: sua meta.',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12),
                  ),
                ),
            ],
            const SectionLabel(
              'Histórico',
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
            ),
            if (list.isEmpty)
              const Text(
                'Nenhum registro de peso.',
                style: TextStyle(color: AppColors.textFaint),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final w in list.reversed)
                      ListTile(
                        dense: true,
                        title: Text('${formatNumber(w.weight)} kg'),
                        subtitle: Text(
                          friendlyDay(
                            dateFromEpochDay(w.day),
                            dateFromEpochDay(today),
                          ),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        trailing: IconButton(
                          tooltip: 'Excluir registro',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Excluir registro',
                              message:
                                  'Apagar o peso de ${formatDate(dateFromEpochDay(w.day))}?',
                              confirmLabel: 'Excluir',
                              destructive: true,
                            );
                            if (ok) await repo.deleteWeight(w.id);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'A meta é definida por você. O app só registra e compara; não '
              'dá orientação de saúde.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12),
            ),
          ],
        );
      }),
    );
  }
}
