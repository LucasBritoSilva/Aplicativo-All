import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/routine_repository.dart';
import '../domain/routine_logic.dart';
import 'activity_form.dart';
import 'routine_widgets.dart';

/// Planejamento: as atividades recorrentes cadastradas pelo usuário.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(routineActivitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Atividades planejadas')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova atividade',
        onPressed: () => openActivityForm(context),
        child: const Icon(Icons.add),
      ),
      body: activities.view((list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'Nenhuma atividade planejada',
            message:
                'Você planeja; o app organiza e acompanha. Toque em + para '
                'cadastrar um compromisso fixo, uma atividade flexível ou um '
                'período de descanso.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ActivityCard(list[i]),
        );
      }),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.activity);

  final RoutineActivity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final when = a.singleDay == null
        ? describeWeekdays(a.weekdays)
        : 'Somente em ${formatDate(dateFromEpochDay(a.singleDay!))}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => openActivityForm(context, activity: a),
        leading: Icon(kindIcon(a.kind), color: AppColors.primary),
        title: Text(a.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatMinute(a.startMinute)}–${formatMinute(a.endMinute)} · $when',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Pill(kindShort(a.kind)),
                  if (a.timerEnabled)
                    const Pill('Cronômetro', icon: Icons.timer_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
