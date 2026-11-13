import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/routine_repository.dart';
import '../data/routine_sync.dart';
import '../domain/routine_logic.dart';
import 'activities_screen.dart';
import 'activity_form.dart';
import 'occurrence_sheet.dart';
import 'reorganize_screen.dart';
import 'resume_list_screen.dart';
import 'routine_history_screen.dart';
import 'routine_widgets.dart';

/// Minha Rotina: a programação do dia (ou da semana) em ordem cronológica.
class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key, this.openOccurrenceId});

  /// Ocorrência a abrir ao entrar (usado ao tocar na notificação).
  final int? openOccurrenceId;

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  late int _day = epochDay(DateTime.now());
  bool _week = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    // Gera as ocorrências que faltam e confere as notificações.
    await ref.read(routineSyncProvider).run();
    final id = widget.openOccurrenceId;
    if (id == null || !mounted) return;
    final view = await ref.read(routineRepositoryProvider).loadOccurrence(id);
    if (view == null || !mounted) return;
    setState(() => _day = view.occ.scheduledDay);
    await showOccurrenceSheet(context, id);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _menu(String value) {
    switch (value) {
      case 'activities':
        _push(const ActivitiesScreen());
      case 'reorganize':
        _push(ReorganizeScreen(day: _day));
      case 'history':
        _push(const RoutineHistoryScreen());
      case 'tolerance':
        askTolerance(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayDate = ref.watch(todayProvider);
    final today = epochDay(todayDate);
    final resumeCount = ref.watch(resumeListProvider).value?.length ?? 0;
    final tolerance = ref.watch(routineToleranceProvider);
    final date = dateFromEpochDay(_day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha rotina'),
        actions: [
          IconButton(
            tooltip: 'Lista de Retomadas',
            icon: Badge(
              isLabelVisible: resumeCount > 0,
              label: Text('$resumeCount'),
              child: const Icon(Icons.replay),
            ),
            onPressed: () => _push(const ResumeListScreen()),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: _menu,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'activities',
                child: Text('Atividades planejadas'),
              ),
              const PopupMenuItem(
                value: 'reorganize',
                child: Text('Reorganizar este dia'),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('Histórico e indicadores'),
              ),
              PopupMenuItem(
                value: 'tolerance',
                child: Text('Tolerância de atraso ($tolerance min)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openActivityForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Atividade'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Dia')),
                  ButtonSegment(value: true, label: Text('Semana')),
                ],
                selected: {_week},
                onSelectionChanged: (s) => setState(() => _week = s.first),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: _week ? 'Semana anterior' : 'Dia anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _day -= _week ? 7 : 1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _day == today
                      ? null
                      : () => setState(() => _day = today),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          _week
                              ? formatWeekRange(date)
                              : friendlyDay(date, todayDate),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_day != today)
                          Text(
                            'Toque para voltar a hoje',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          )
                        else if (!_week)
                          Text(
                            '${weekdayLong(date)}, ${formatDayMonth(date)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _week ? 'Próxima semana' : 'Próximo dia',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _day += _week ? 7 : 1),
              ),
            ],
          ),
          Expanded(
            child: _week
                ? _WeekView(
                    anchorDay: _day,
                    today: today,
                    onOpenDay: (day) => setState(() {
                      _day = day;
                      _week = false;
                    }),
                  )
                : _DayView(day: _day, today: today),
          ),
        ],
      ),
    );
  }
}

class _DayView extends ConsumerWidget {
  const _DayView({required this.day, required this.today});

  final int day;
  final int today;

  /// A atividade em destaque: a que está em andamento, a pausada ou a
  /// próxima pendente. É por ela que o botão Iniciar fica sempre à mão.
  DayEntry? _focus(List<DayEntry> entries, DateTime now) {
    final open = [
      for (final e in entries)
        if (e.view.occ.kind != ActivityKind.rest &&
            (e.kind == DayEntryKind.continuation ||
                ((e.kind == DayEntryKind.normal ||
                        e.kind == DayEntryKind.fromPreviousDay) &&
                    (e.view.occ.status == OccurrenceStatus.pending ||
                        e.view.occ.status == OccurrenceStatus.inProgress ||
                        e.view.occ.status == OccurrenceStatus.paused))))
          e,
    ];
    if (open.isEmpty) return null;
    for (final status in [
      OccurrenceStatus.inProgress,
      OccurrenceStatus.paused,
    ]) {
      for (final e in open) {
        if (e.view.occ.status == status) return e;
      }
    }
    final minute = minuteOfDay(now);
    for (final e in open) {
      if (e.end > minute) return e;
    }
    return open.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(routineDayProvider(day));
    final tolerance = ref.watch(routineToleranceProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return views.view((list) {
      final entries = buildDayEntries(list, day);
      if (entries.isEmpty) {
        return const EmptyState(
          icon: Icons.wb_sunny_outlined,
          title: 'Nada planejado para este dia',
          message:
              'Toque em "Atividade" para planejar um compromisso fixo, uma '
              'atividade flexível ou um período de descanso.',
        );
      }
      final summary = summarizeRoutine([
        for (final e in entries)
          if (e.kind == DayEntryKind.normal)
            (
              status: e.view.occ.status,
              kind: e.view.occ.kind,
              timerSeconds: e.view.occ.timerEnabled
                  ? e.view.doneSeconds(now)
                  : 0,
            ),
      ]);
      final focus = day == today ? _focus(entries, now) : null;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (summary.planned > 0) _ProgressCard(summary),
          if (focus != null) ...[
            const SizedBox(height: 8),
            _FocusCard(entry: focus, now: now, tolerance: tolerance),
          ],
          const SizedBox(height: 8),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EntryCard(entry: e, now: now, tolerance: tolerance),
            ),
        ],
      );
    });
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard(this.summary);

  final RoutineSummary summary;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (summary.partial > 0)
        summary.partial == 1 ? '1 parcial' : '${summary.partial} parciais',
      if (summary.notDone > 0)
        summary.notDone == 1
            ? '1 não realizada'
            : '${summary.notDone} não realizadas',
      if (summary.open > 0) '${summary.open} em aberto',
      if (summary.timerSeconds > 0)
        '${formatDuration(summary.timerSeconds)} registrados',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.done} de ${summary.planned} '
              '${summary.done == 1 ? 'concluída' : 'concluídas'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ProgressBar(value: summary.completionRate),
            if (parts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                parts.join(' · '),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cartão grande da atividade atual ou da próxima, com o botão principal.
class _FocusCard extends ConsumerWidget {
  const _FocusCard({
    required this.entry,
    required this.now,
    required this.tolerance,
  });

  final DayEntry entry;
  final DateTime now;
  final int tolerance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = entry.view;
    final occ = view.occ;
    final state = view.state(now, tolerance);
    final actions = ref.read(routineActionsProvider);
    final running = occ.status == OccurrenceStatus.inProgress;
    final paused = occ.status == OccurrenceStatus.paused;

    final (label, icon, run) = switch (occ.status) {
      OccurrenceStatus.inProgress => (
        'Pausar',
        Icons.pause,
        () => actions.pause(occ.id),
      ),
      OccurrenceStatus.paused => (
        'Continuar',
        Icons.play_arrow,
        () => actions.resume(occ.id),
      ),
      OccurrenceStatus.awaitingResume => (
        'Continuar agora',
        Icons.play_arrow,
        () => actions.start(occ.id),
      ),
      _ => (
        state == DisplayState.late ? 'Iniciar agora' : 'Iniciar',
        Icons.play_arrow,
        () => actions.start(occ.id),
      ),
    };

    return Card(
      color: AppColors.surfaceHigh,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showOccurrenceSheet(context, occ.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      running || paused ? 'AGORA' : 'PRÓXIMA ATIVIDADE',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  StatePill(state),
                ],
              ),
              const SizedBox(height: 8),
              Text(occ.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                entry.kind == DayEntryKind.fromPreviousDay
                    ? 'Começou ontem às ${formatMinute(occ.scheduledStart)} · '
                          'termina às ${formatMinute(entry.end)}'
                    : formatSpan(entry.start, entry.end),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (occ.timerEnabled && view.sessions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  formatClock(view.doneSeconds(now)),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: () => runRoutineAction(context, run),
                      icon: Icon(icon),
                      label: Text(label),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => runRoutineAction(
                        context,
                        () => actions.conclude(occ.id),
                        success: 'Atividade concluída.',
                      ),
                      child: const Text('Concluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.entry,
    required this.now,
    required this.tolerance,
  });

  final DayEntry entry;
  final DateTime now;
  final int tolerance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = entry.view;
    final occ = view.occ;
    final state = view.state(now, tolerance);
    final moved = entry.kind == DayEntryKind.movedAway;
    final continuation = entry.kind == DayEntryKind.continuation;
    final fromYesterday = entry.kind == DayEntryKind.fromPreviousDay;
    final closed = state.isClosed;
    final faded = moved || closed;
    final actions = ref.read(routineActionsProvider);

    Widget? quick;
    if (!moved && occ.kind != ActivityKind.rest) {
      switch (occ.status) {
        case OccurrenceStatus.pending || OccurrenceStatus.awaitingResume:
          quick = IconButton.filledTonal(
            tooltip: occ.status == OccurrenceStatus.pending
                ? 'Iniciar'
                : 'Continuar agora',
            icon: const Icon(Icons.play_arrow),
            onPressed: () =>
                runRoutineAction(context, () => actions.start(occ.id)),
          );
        case OccurrenceStatus.inProgress:
          quick = IconButton.filledTonal(
            tooltip: 'Pausar',
            icon: const Icon(Icons.pause),
            onPressed: () =>
                runRoutineAction(context, () => actions.pause(occ.id)),
          );
        case OccurrenceStatus.paused:
          quick = IconButton.filledTonal(
            tooltip: 'Continuar',
            icon: const Icon(Icons.play_arrow),
            onPressed: () =>
                runRoutineAction(context, () => actions.resume(occ.id)),
          );
        case OccurrenceStatus.done ||
            OccurrenceStatus.partial ||
            OccurrenceStatus.notDone:
          quick = null;
      }
    }

    final todayDate = dateOnly(now);
    final extra = <String>[
      if (moved)
        'Reagendada para '
            '${friendlyDay(dateFromEpochDay(occ.scheduledDay), todayDate)}, '
            '${formatMinute(occ.scheduledStart)}',
      if (fromYesterday)
        'Continua de ontem (começou às ${formatMinute(occ.scheduledStart)})',
      if (!fromYesterday && crossesMidnight(entry.end))
        'Termina amanhã às ${formatMinute(entry.end)}',
      if (!moved && !continuation && !fromYesterday && occ.rescheduled)
        'Planejada para '
            '${formatDayMonthNumeric(dateFromEpochDay(occ.originalDay))}, '
            '${formatMinute(occ.plannedStart)}',
      if (!moved && occ.timerEnabled && view.sessions.isNotEmpty)
        '${formatDuration(view.doneSeconds(now))} de '
            '${formatDuration(view.plannedSecs)}',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showOccurrenceSheet(context, occ.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMinute(entry.start),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: faded ? AppColors.textFaint : AppColors.text,
                      ),
                    ),
                    Text(
                      formatMinute(entry.end),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      continuation ? 'Retomada: ${occ.name}' : occ.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: faded ? AppColors.textMuted : AppColors.text,
                        decoration: moved ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(kindShort(occ.kind), icon: kindIcon(occ.kind)),
                        if (moved)
                          Pill(
                            'Reagendada',
                            color: AppColors.primaryDim,
                            icon: Icons.event_repeat,
                          )
                        else if (occ.kind != ActivityKind.rest)
                          StatePill(state),
                      ],
                    ),
                    for (final line in extra)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?quick,
            ],
          ),
        ),
      ),
    );
  }
}

/// Visão semanal: os sete dias, com as atividades de cada um.
class _WeekView extends ConsumerWidget {
  const _WeekView({
    required this.anchorDay,
    required this.today,
    required this.onOpenDay,
  });

  final int anchorDay;
  final int today;
  final ValueChanged<int> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = epochDay(startOfWeek(dateFromEpochDay(anchorDay)));
    final views = ref.watch(routineRangeProvider((start, start + 6)));
    final tolerance = ref.watch(routineToleranceProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return views.view((list) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          for (var day = start; day <= start + 6; day++)
            _WeekDayCard(
              day: day,
              isToday: day == today,
              entries: buildDayEntries(
                list,
                day,
              ).where((e) => e.kind != DayEntryKind.movedAway).toList(),
              now: now,
              tolerance: tolerance,
              onOpenDay: () => onOpenDay(day),
            ),
        ],
      );
    });
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.day,
    required this.isToday,
    required this.entries,
    required this.now,
    required this.tolerance,
    required this.onOpenDay,
  });

  final int day;
  final bool isToday;
  final List<DayEntry> entries;
  final DateTime now;
  final int tolerance;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final date = dateFromEpochDay(day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpenDay,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${weekdayLong(date)}, ${formatDayMonth(date)}'
                        '${isToday ? ' · hoje' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.primary : AppColors.text,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textFaint),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  'Nada planejado',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 13),
                ),
              )
            else
              for (final e in entries)
                InkWell(
                  onTap: () => showOccurrenceSheet(context, e.view.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                    child: Row(
                      children: [
                        Icon(
                          e.view.occ.kind == ActivityKind.rest
                              ? Icons.spa_outlined
                              : stateIcon(e.view.state(now, tolerance)),
                          size: 16,
                          color: e.view.occ.kind == ActivityKind.rest
                              ? AppColors.textFaint
                              : stateColor(e.view.state(now, tolerance)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.kind == DayEntryKind.fromPreviousDay
                              ? 'até ${formatMinute(e.end)}'
                              : formatSpan(
                                  e.start,
                                  e.end,
                                ).replaceAll(' (dia seguinte)', ' (+1)'),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            switch (e.kind) {
                              DayEntryKind.continuation =>
                                'Retomada: ${e.view.occ.name}',
                              DayEntryKind.fromPreviousDay =>
                                '${e.view.occ.name} (continua de ontem)',
                              _ => e.view.occ.name,
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
