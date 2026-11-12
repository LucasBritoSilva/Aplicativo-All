import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/routine_repository.dart';
import '../domain/routine_logic.dart';
import 'occurrence_sheet.dart';

/// Lista de Retomadas: atividades interrompidas que o usuário decidiu
/// continuar depois, sem marcar horário.
///
/// A ordem é sempre a mesma: mais antigas primeiro, pela data de entrada
/// na lista. Consultar um item não muda a posição dele, e nada sai daqui
/// sozinho: só quando a ocorrência é concluída, encerrada ou reagendada.
class ResumeListScreen extends ConsumerWidget {
  const ResumeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(resumeListProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Retomadas')),
      body: list.view((items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.replay,
            title: 'Nenhuma retomada pendente',
            message:
                'Quando você interromper uma atividade e escolher '
                '"Adicionar à Lista de Retomadas", ela fica guardada aqui, '
                'com o progresso preservado.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _ResumeCard(position: i + 1, view: items[i], now: now),
        );
      }),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.position,
    required this.view,
    required this.now,
  });

  final int position;
  final OccurrenceView view;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final occ = view.occ;
    final done = view.doneSeconds(now);
    final planned = view.plannedSecs;
    const muted = TextStyle(color: AppColors.textMuted, fontSize: 13);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showOccurrenceSheet(context, view.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceHigh,
                child: Text(
                  '$position',
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occ.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data original: '
                      '${formatDate(dateFromEpochDay(occ.originalDay))}',
                      style: muted,
                    ),
                    Text(
                      'Na lista desde: '
                      '${formatDate(view.resume!.listEnteredAt!)}',
                      style: muted,
                    ),
                    Text(
                      occ.timerEnabled
                          ? 'Planejado ${formatDuration(planned)} · '
                                'realizado ${formatDuration(done)} · '
                                'restam ${formatDuration(remainingSeconds(planned, done))}'
                          : 'Planejado ${formatDuration(planned)}',
                      style: muted,
                    ),
                    const SizedBox(height: 8),
                    const Pill(
                      'Aguardando retomada',
                      color: AppColors.info,
                      icon: Icons.replay,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
