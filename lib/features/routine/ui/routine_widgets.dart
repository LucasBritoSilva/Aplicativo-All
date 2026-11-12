import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/routine_repository.dart';
import '../domain/routine_logic.dart';

Color stateColor(DisplayState state) => switch (state) {
  DisplayState.pending => AppColors.textMuted,
  DisplayState.inProgress => AppColors.primary,
  DisplayState.paused => AppColors.warning,
  DisplayState.late => AppColors.danger,
  DisplayState.awaitingResume => AppColors.info,
  DisplayState.done => AppColors.success,
  DisplayState.partial => AppColors.warning,
  DisplayState.notDone => AppColors.textFaint,
  DisplayState.rescheduled => AppColors.primaryDim,
};

IconData stateIcon(DisplayState state) => switch (state) {
  DisplayState.pending => Icons.radio_button_unchecked,
  DisplayState.inProgress => Icons.play_circle_outline,
  DisplayState.paused => Icons.pause_circle_outline,
  DisplayState.late => Icons.error_outline,
  DisplayState.awaitingResume => Icons.replay,
  DisplayState.done => Icons.check_circle_outline,
  DisplayState.partial => Icons.incomplete_circle,
  DisplayState.notDone => Icons.cancel_outlined,
  DisplayState.rescheduled => Icons.event_repeat,
};

String kindShort(ActivityKind kind) => switch (kind) {
  ActivityKind.fixed => 'Fixo',
  ActivityKind.flexible => 'Flexível',
  ActivityKind.rest => 'Descanso',
};

IconData kindIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.fixed => Icons.push_pin_outlined,
  ActivityKind.flexible => Icons.swap_vert,
  ActivityKind.rest => Icons.spa_outlined,
};

/// Etiqueta colorida com o estado da ocorrência.
class StatePill extends StatelessWidget {
  const StatePill(this.state, {super.key});

  final DisplayState state;

  @override
  Widget build(BuildContext context) =>
      Pill(state.label, color: stateColor(state), icon: stateIcon(state));
}

/// Executa uma ação da rotina e mostra a mensagem certa se a regra
/// não permitir (por exemplo, a atividade mudou de estado em outra tela).
Future<bool> runRoutineAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) showMessage(context, success);
    return true;
  } on RoutineStateError catch (e) {
    if (context.mounted) showMessage(context, e.message);
    return false;
  }
}

typedef Slot = ({int day, int start, int end});

/// Pergunta data e horário e confere conflitos antes de devolver.
///
/// Se o horário se sobrepõe a outra atividade, o app informa quais são e
/// o usuário decide se mantém. Nada é movido automaticamente.
Future<Slot?> askSchedule(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required int day,
  required int start,
  required int end,
  int? ignoreId,
}) async {
  final repo = ref.read(routineRepositoryProvider);
  final result = await showQuickForm(
    context,
    title: title,
    submitLabel: 'Confirmar',
    fields: [
      DateSpec('day', 'Data', initial: dateFromEpochDay(day), required: true),
      TimeSpec('start', 'Início', initial: start, required: true),
      TimeSpec('end', 'Término', initial: end, required: true),
    ],
    validate: (v) => v.time('end')! <= v.time('start')!
        ? 'O término precisa ser depois do início.'
        : null,
  );
  if (result == null) return null;
  final slot = (
    day: epochDay(result.date('day')!),
    start: result.time('start')!,
    end: result.time('end')!,
  );
  final conflicts = findConflicts(
    day: slot.day,
    start: slot.start,
    end: slot.end,
    blocks: await repo.blocksOn(slot.day),
    ignoreId: ignoreId,
  );
  if (conflicts.isEmpty) return slot;
  if (!context.mounted) return null;
  final keep = await confirm(
    context,
    title: 'Conflito de horário',
    message:
        'Esse horário se sobrepõe a:\n\n'
        '${conflicts.map((c) => '• ${describeConflict(c)}').join('\n')}\n\n'
        'Deseja manter esse horário mesmo assim?',
    confirmLabel: 'Manter',
  );
  return keep ? slot : null;
}

/// Configuração da tolerância de atraso.
Future<void> askTolerance(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(routineRepositoryProvider);
  final result = await showQuickForm(
    context,
    title: 'Tolerância de atraso',
    fields: [
      NumberSpec(
        'minutes',
        'Minutos de tolerância',
        initial: ref.read(routineToleranceProvider).toDouble(),
        required: true,
        decimal: false,
        min: 0,
        max: 240,
        suffix: 'min',
      ),
    ],
  );
  if (result == null) return;
  await repo.setTolerance(result.integer('minutes')!);
}

/// Linha "ícone + rótulo + valor" usada nos detalhes.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
