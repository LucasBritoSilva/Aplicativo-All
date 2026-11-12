import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/routine_repository.dart';
import '../domain/routine_logic.dart';
import 'occurrence_sheet.dart';
import 'routine_widgets.dart';

enum _HistoryFilter {
  all('Todas'),
  done('Concluídas'),
  partial('Parciais'),
  notDone('Não realizadas'),
  rescheduled('Reagendadas'),
  open('Em aberto');

  const _HistoryFilter(this.label);
  final String label;
}

/// Histórico das ocorrências e indicadores de constância.
class RoutineHistoryScreen extends ConsumerStatefulWidget {
  const RoutineHistoryScreen({super.key});

  @override
  ConsumerState<RoutineHistoryScreen> createState() =>
      _RoutineHistoryScreenState();
}

class _RoutineHistoryScreenState extends ConsumerState<RoutineHistoryScreen> {
  int _days = 7;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final today = epochDay(ref.watch(todayProvider));
    final range = (today - _days + 1, today);
    final views = ref.watch(routineRangeProvider(range));
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final tolerance = ref.watch(routineToleranceProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Histórico da rotina'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Histórico'),
              Tab(text: 'Indicadores'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            FilterBar<int>(
              options: const [
                (7, 'Últimos 7 dias'),
                (30, '30 dias'),
                (90, '90 dias'),
              ],
              selected: _days,
              onSelected: (v) => setState(() => _days = v),
            ),
            Expanded(
              child: views.view((list) {
                // Só o que acontece dentro do período, sem descanso.
                final inRange = [
                  for (final v in list)
                    if (v.occ.kind != ActivityKind.rest &&
                        v.occ.scheduledDay >= range.$1 &&
                        v.occ.scheduledDay <= range.$2)
                      v,
                ];
                return TabBarView(
                  children: [
                    _HistoryTab(
                      views: inRange,
                      now: now,
                      tolerance: tolerance,
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                    ),
                    _IndicatorsTab(
                      views: inRange,
                      now: now,
                      today: today,
                      days: _days,
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.views,
    required this.now,
    required this.tolerance,
    required this.filter,
    required this.onFilter,
  });

  final List<OccurrenceView> views;
  final DateTime now;
  final int tolerance;
  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onFilter;

  bool _matches(OccurrenceView v) => switch (filter) {
    _HistoryFilter.all => true,
    _HistoryFilter.done => v.occ.status == OccurrenceStatus.done,
    _HistoryFilter.partial => v.occ.status == OccurrenceStatus.partial,
    _HistoryFilter.notDone => v.occ.status == OccurrenceStatus.notDone,
    _HistoryFilter.rescheduled => v.occ.rescheduled,
    _HistoryFilter.open => !v.state(now, tolerance).isClosed,
  };

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(now);
    final shown = views.where(_matches).toList()
      ..sort((a, b) {
        final byDay = b.occ.scheduledDay.compareTo(a.occ.scheduledDay);
        return byDay != 0
            ? byDay
            : a.occ.scheduledStart.compareTo(b.occ.scheduledStart);
      });
    return Column(
      children: [
        FilterBar<_HistoryFilter>(
          options: [for (final f in _HistoryFilter.values) (f, f.label)],
          selected: filter,
          onSelected: onFilter,
        ),
        Expanded(
          child: shown.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'Nada neste período',
                  message: 'As atividades planejadas aparecem aqui com o que '
                      'realmente aconteceu em cada dia.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final v = shown[i];
                    final occ = v.occ;
                    final done = v.doneSeconds(now);
                    final details = [
                      'Planejado ${formatDuration(v.plannedSecs)}',
                      if (occ.timerEnabled) 'realizado ${formatDuration(done)}',
                      if (v.sessions.isNotEmpty)
                        v.sessions.length == 1
                            ? '1 sessão'
                            : '${v.sessions.length} sessões',
                    ].join(' · ');
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () => showOccurrenceSheet(context, v.id),
                        title: Text(occ.name),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${friendlyDay(dateFromEpochDay(occ.scheduledDay), today)}'
                                ' · ${formatMinute(occ.scheduledStart)}–${formatMinute(occ.scheduledEnd)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (occ.rescheduled)
                                Text(
                                  'Reagendada (era '
                                  '${formatDayMonthNumeric(dateFromEpochDay(occ.originalDay))}, '
                                  '${formatMinute(occ.plannedStart)})',
                                  style: const TextStyle(
                                    color: AppColors.textFaint,
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                details,
                                style: const TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              StatePill(v.state(now, tolerance)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _IndicatorsTab extends StatelessWidget {
  const _IndicatorsTab({
    required this.views,
    required this.now,
    required this.today,
    required this.days,
  });

  final List<OccurrenceView> views;
  final DateTime now;
  final int today;
  final int days;

  RoutineSummary _summary(Iterable<OccurrenceView> list) => summarizeRoutine([
    for (final v in list)
      (
        status: v.occ.status,
        kind: v.occ.kind,
        timerSeconds: v.occ.timerEnabled ? v.doneSeconds(now) : 0,
      ),
  ]);

  @override
  Widget build(BuildContext context) {
    if (views.isEmpty) {
      return const EmptyState(
        icon: Icons.insights,
        title: 'Sem dados neste período',
        message: 'Os indicadores aparecem conforme você usa a rotina.',
      );
    }
    final total = _summary(views);

    // Evolução diária: no máximo os últimos 14 dias, para caber na tela.
    final span = days > 14 ? 14 : days;
    final bars = [
      for (var day = today - span + 1; day <= today; day++)
        () {
          final s = _summary(views.where((v) => v.occ.scheduledDay == day));
          return BarData('${dateFromEpochDay(day).day}', [
            (s.done.toDouble(), AppColors.success),
            (s.partial.toDouble(), AppColors.warning),
            (s.notDone.toDouble(), AppColors.textFaint),
            (s.open.toDouble(), AppColors.outline),
          ]);
        }(),
    ];

    // Frequência de cumprimento por atividade.
    final byActivity = <int, List<OccurrenceView>>{};
    for (final v in views) {
      (byActivity[v.occ.activityId] ??= []).add(v);
    }
    final frequency = [
      for (final group in byActivity.values)
        (name: group.last.occ.name, summary: _summary(group)),
    ]..sort((a, b) => b.summary.planned.compareTo(a.summary.planned));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        StatRow(
          tiles: [
            StatTile(value: '${total.planned}', label: 'Planejadas'),
            StatTile(
              value: '${total.done}',
              label: 'Concluídas',
              color: AppColors.success,
            ),
            StatTile(
              value: '${total.partial}',
              label: 'Parciais',
              color: AppColors.warning,
            ),
            StatTile(value: '${total.notDone}', label: 'Não realizadas'),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(
                  icon: Icons.task_alt,
                  label: 'Conclusão total',
                  value: '${(total.completionRate * 100).round()}% do planejado',
                ),
                InfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Tempo registrado',
                  value: formatDuration(total.timerSeconds),
                ),
                InfoRow(
                  icon: Icons.hourglass_empty,
                  label: 'Em aberto',
                  value:
                      '${total.open} (ainda sem desfecho; não contam como falha)',
                ),
              ],
            ),
          ),
        ),
        const SectionLabel(
          'Evolução diária',
          padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SimpleBarChart(bars: bars),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Legend('Concluídas', AppColors.success),
                    _Legend('Parciais', AppColors.warning),
                    _Legend('Não realizadas', AppColors.textFaint),
                    _Legend('Em aberto', AppColors.outline),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SectionLabel(
          'Frequência por atividade',
          padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final f in frequency)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(f.name)),
                            Text(
                              '${f.summary.done} de ${f.summary.planned}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(value: f.summary.completionRate),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
