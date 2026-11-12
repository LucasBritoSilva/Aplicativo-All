import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../data/routine_repository.dart';
import '../data/routine_sync.dart';
import '../domain/routine_logic.dart';
import 'routine_widgets.dart';

/// Abre os detalhes de uma ocorrência, com as ações do estado atual.
Future<void> showOccurrenceSheet(BuildContext context, int occurrenceId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OccurrenceSheet(occurrenceId),
  );
}

class _OccurrenceSheet extends ConsumerWidget {
  const _OccurrenceSheet(this.occurrenceId);

  final int occurrenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(occurrenceProvider(occurrenceId));
    final tolerance = ref.watch(routineToleranceProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: view.when(
        loading: () => const SizedBox(height: 160, child: Loading()),
        error: (e, _) => ErrorText(e),
        data: (v) => v == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Esta atividade não existe mais.'),
              )
            : _Content(view: v, now: now, tolerance: tolerance),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.view,
    required this.now,
    required this.tolerance,
  });

  final OccurrenceView view;
  final DateTime now;
  final int tolerance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occ = view.occ;
    final state = view.state(now, tolerance);
    final today = dateOnly(now);
    final done = view.doneSeconds(now);
    final planned = view.plannedSecs;
    final resume = view.resume;

    String slot(int day, int start, int end) =>
        '${friendlyDay(dateFromEpochDay(day), today)} · '
        '${formatMinute(start)}–${formatMinute(end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(occ.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(kindShort(occ.kind), icon: kindIcon(occ.kind)),
            StatePill(state),
          ],
        ),
        const SizedBox(height: 14),
        InfoRow(
          icon: Icons.event_outlined,
          label: 'Planejado',
          value:
              '${slot(occ.originalDay, occ.plannedStart, occ.plannedEnd)} '
              '(${formatDuration(planned)})',
        ),
        if (occ.rescheduled)
          InfoRow(
            icon: Icons.event_repeat,
            label: 'Reagendado para',
            value: slot(occ.scheduledDay, occ.scheduledStart, occ.scheduledEnd),
          ),
        if (view.hasContinuation)
          InfoRow(
            icon: Icons.replay,
            label: 'Continuação marcada',
            value: slot(
              resume!.scheduledDay!,
              resume.scheduledStart ?? 0,
              resume.scheduledEnd ?? 0,
            ),
          ),
        if (view.inResumeList)
          InfoRow(
            icon: Icons.playlist_add_check,
            label: 'Na Lista de Retomadas desde',
            value: formatDate(resume!.listEnteredAt!),
          ),
        if (occ.closedAt != null)
          InfoRow(
            icon: Icons.flag_outlined,
            label: 'Encerrada em',
            value: '${formatDate(occ.closedAt!)} às ${formatTime(occ.closedAt!)}',
          ),
        if (occ.timerEnabled && occ.kind != ActivityKind.rest) ...[
          const SizedBox(height: 12),
          _TimerBlock(done: done, planned: planned),
        ],
        if (view.sessions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            view.sessions.length == 1
                ? '1 sessão'
                : '${view.sessions.length} sessões',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          for (final (i, s) in view.sessions.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(_sessionLine(i, s, occ.timerEnabled)),
            ),
        ],
        const SizedBox(height: 18),
        ..._actions(context, ref, state),
      ],
    );
  }

  String _sessionLine(int index, RoutineSession s, bool timer) {
    final end = s.endedAt == null ? 'em aberto' : formatTime(s.endedAt!);
    final base =
        'Sessão ${index + 1}: ${formatDayMonthNumeric(s.startedAt)}, '
        '${formatTime(s.startedAt)}–$end';
    if (!timer) return base;
    final secs = sessionSeconds(
      accumulatedSeconds: s.accumulatedSeconds,
      runningSince: s.runningSince,
      now: now,
    );
    return '$base · ${formatDuration(secs)}';
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, DisplayState state) {
    final actions = ref.read(routineActionsProvider);
    final id = view.id;
    const gap = SizedBox(height: 8);

    Widget primary(String label, IconData icon, VoidCallback onPressed) =>
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );
    Widget secondary(String label, IconData icon, VoidCallback onPressed) =>
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );

    Future<void> closeWith(Future<void> Function() action, String message) async {
      final ok = await runRoutineAction(context, action);
      if (ok && context.mounted) {
        Navigator.pop(context);
        showMessage(context, message);
      }
    }

    final conclude = secondary(
      'Marcar como concluída',
      Icons.check,
      () => closeWith(() => actions.conclude(id), 'Atividade concluída.'),
    );

    if (view.occ.kind == ActivityKind.rest) {
      return [
        if (view.occ.status == OccurrenceStatus.pending)
          secondary(
            'Mudar o horário deste dia',
            Icons.event_repeat,
            () => _reschedule(context, ref),
          ),
      ];
    }

    switch (view.occ.status) {
      case OccurrenceStatus.pending:
        return [
          primary(
            state == DisplayState.late
                ? 'Tentar novamente (iniciar agora)'
                : 'Iniciar',
            Icons.play_arrow,
            () => runRoutineAction(context, () => actions.start(id)),
          ),
          gap,
          conclude,
          gap,
          secondary(
            'Reagendar manualmente',
            Icons.event_repeat,
            () => _reschedule(context, ref),
          ),
          gap,
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              final ok = await confirm(
                context,
                title: 'Registrar como não realizada?',
                message:
                    'Esta ocorrência será encerrada sem execução e ficará '
                    'no histórico. As próximas repetições continuam '
                    'programadas normalmente.',
                confirmLabel: 'Registrar',
              );
              if (ok) {
                await closeWith(
                  () => actions.markNotDone(id),
                  'Registrada como não realizada.',
                );
              }
            },
            child: const Text('Registrar como não realizada'),
          ),
        ];
      case OccurrenceStatus.inProgress:
        return [
          primary(
            'Pausar',
            Icons.pause,
            () => runRoutineAction(context, () => actions.pause(id)),
          ),
          gap,
          conclude,
          gap,
          secondary(
            'Interromper...',
            Icons.stop_circle_outlined,
            () => _interrupt(context, ref),
          ),
        ];
      case OccurrenceStatus.paused:
        return [
          primary(
            'Continuar',
            Icons.play_arrow,
            () => runRoutineAction(context, () => actions.resume(id)),
          ),
          gap,
          conclude,
          gap,
          secondary(
            'Interromper...',
            Icons.stop_circle_outlined,
            () => _interrupt(context, ref),
          ),
        ];
      case OccurrenceStatus.awaitingResume:
        return [
          primary(
            'Continuar agora',
            Icons.play_arrow,
            () => runRoutineAction(context, () => actions.start(id)),
          ),
          gap,
          secondary(
            'Reagendar manualmente',
            Icons.event_repeat,
            () => _scheduleContinuation(context, ref),
          ),
          if (view.hasContinuation) ...[
            gap,
            secondary(
              'Mover para a Lista de Retomadas',
              Icons.playlist_add,
              () => runRoutineAction(
                context,
                () => actions.addToResumeList(id),
                success: 'Guardada na Lista de Retomadas.',
              ),
            ),
          ],
          gap,
          secondary(
            'Encerrar como parcial',
            Icons.incomplete_circle,
            () => closeWith(
              () => actions.closePartial(id),
              'Encerrada como parcial.',
            ),
          ),
          gap,
          conclude,
        ];
      case OccurrenceStatus.done ||
          OccurrenceStatus.partial ||
          OccurrenceStatus.notDone:
        return [
          secondary(
            'Desfazer encerramento',
            Icons.undo,
            () => runRoutineAction(
              context,
              () => actions.reopen(id),
              success: 'Encerramento desfeito.',
            ),
          ),
        ];
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(routineActionsProvider);
    final occ = view.occ;
    final slot = await askSchedule(
      context,
      ref,
      title: 'Reagendar: ${occ.name}',
      day: occ.scheduledDay,
      start: occ.scheduledStart,
      end: occ.scheduledEnd,
      ignoreId: occ.id,
    );
    if (slot == null || !context.mounted) return;
    await runRoutineAction(
      context,
      () => actions.reschedule(
        occ.id,
        day: slot.day,
        start: slot.start,
        end: slot.end,
      ),
      success: 'Atividade reagendada. As outras repetições não mudaram.',
    );
  }

  /// Opções para uma atividade iniciada e interrompida.
  Future<void> _interrupt(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(routineActionsProvider);
    final choice = await _choose(context, 'Interromper atividade', const [
      (
        'later',
        'Continuar mais tarde',
        'Guarda o progresso para retomar depois',
      ),
      (
        'partial',
        'Encerrar como parcial',
        'Registra o que foi feito e encerra esta ocorrência',
      ),
      (
        'done',
        'Marcar como concluída',
        'Vale mesmo com menos tempo que o planejado',
      ),
    ]);
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'later':
        await _continueLater(context, ref);
      case 'partial':
        final ok = await runRoutineAction(
          context,
          () => actions.closePartial(view.id),
        );
        if (ok && context.mounted) {
          Navigator.pop(context);
          showMessage(context, 'Encerrada como parcial.');
        }
      case 'done':
        final ok = await runRoutineAction(
          context,
          () => actions.conclude(view.id),
        );
        if (ok && context.mounted) {
          Navigator.pop(context);
          showMessage(context, 'Atividade concluída.');
        }
    }
  }

  Future<void> _continueLater(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(routineActionsProvider);
    final choice = await _choose(context, 'Continuar mais tarde', const [
      (
        'schedule',
        'Reagendar a continuação',
        'Escolher agora a data e o horário para retomar',
      ),
      (
        'list',
        'Adicionar à Lista de Retomadas',
        'Guardar e decidir depois quando continuar',
      ),
    ]);
    if (choice == null || !context.mounted) return;
    if (choice == 'schedule') {
      await _scheduleContinuation(context, ref);
    } else {
      await runRoutineAction(
        context,
        () => actions.addToResumeList(view.id),
        success: 'Guardada na Lista de Retomadas.',
      );
    }
  }

  Future<void> _scheduleContinuation(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(routineActionsProvider);
    final current = DateTime.now();
    // Sugere o tempo que falta (ou a duração planejada, sem cronômetro).
    final missing = view.occ.timerEnabled
        ? remainingSeconds(view.plannedSecs, view.doneSeconds(current))
        : view.plannedSecs;
    var minutes = (missing / 60).ceil();
    if (minutes < 5) minutes = 5;
    var day = epochDay(current);
    var start = ((minuteOfDay(current) + 15) ~/ 5) * 5;
    if (start + minutes > 1439) {
      day += 1;
      start = view.occ.plannedStart;
    }
    var end = start + minutes;
    if (end > 1439) end = 1439;

    final slot = await askSchedule(
      context,
      ref,
      title: 'Continuar: ${view.occ.name}',
      day: day,
      start: start,
      end: end,
      ignoreId: view.id,
    );
    if (slot == null || !context.mounted) return;
    await runRoutineAction(
      context,
      () => actions.scheduleContinuation(
        view.id,
        day: slot.day,
        start: slot.start,
        end: slot.end,
      ),
      success: 'Continuação marcada. O progresso foi preservado.',
    );
  }

  Future<String?> _choose(
    BuildContext context,
    String title,
    List<(String, String, String)> options,
  ) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: [
          for (final (value, label, hint) in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimerBlock extends StatelessWidget {
  const _TimerBlock({required this.done, required this.planned});

  final int done;
  final int planned;

  @override
  Widget build(BuildContext context) {
    final remaining = remainingSeconds(planned, done);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            formatClock(done),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          ProgressBar(value: planned == 0 ? 0 : done / planned),
          const SizedBox(height: 8),
          Text(
            'Planejado: ${formatDuration(planned)} · '
            '${remaining == 0 ? 'tempo planejado cumprido' : 'restam ${formatDuration(remaining)}'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
