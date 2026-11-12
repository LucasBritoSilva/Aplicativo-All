import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/extras.dart';
import '../data/stats_repository.dart';

/// Estatísticas pessoais: indicadores derivados dos registros reais.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider(_days));
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas pessoais')),
      body: Column(
        children: [
          FilterBar<int>(
            options: const [
              (7, '7 dias'),
              (30, '30 dias'),
              (90, '90 dias'),
              (365, '1 ano'),
            ],
            selected: _days,
            onSelected: (d) => setState(() => _days = d),
          ),
          Expanded(child: stats.view((s) => _Body(s))),
        ],
      ),
    );
  }
}

String _pct(double v) => '${(v * 100).round()}%';

class _Body extends StatelessWidget {
  const _Body(this.s);

  final StatsSnapshot s;

  @override
  Widget build(BuildContext context) {
    final r = s.routine;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _Section(
          icon: Icons.check_circle_outline,
          title: 'Tarefas',
          empty: s.tasksCompleted == 0 && s.tasksPending == 0,
          child: StatRow(
            tiles: [
              StatTile(
                value: '${s.tasksCompleted}',
                label: 'Concluídas no período',
                color: AppColors.success,
              ),
              StatTile(value: '${s.tasksPending}', label: 'Pendentes agora'),
            ],
          ),
        ),
        _Section(
          icon: Icons.wb_sunny_outlined,
          title: 'Rotina',
          empty: r.planned == 0,
          child: Column(
            children: [
              StatRow(
                tiles: [
                  StatTile(value: '${r.planned}', label: 'Planejadas'),
                  StatTile(
                    value: '${r.done}',
                    label: 'Concluídas',
                    color: AppColors.success,
                  ),
                  StatTile(
                    value: '${r.partial}',
                    label: 'Parciais',
                    color: AppColors.warning,
                  ),
                  StatTile(value: '${r.notDone}', label: 'Não realizadas'),
                ],
              ),
              _Note(
                'Conclusão total: ${_pct(r.completionRate)} · tempo registrado: '
                '${formatDuration(r.timerSeconds)} · em aberto: ${r.open}',
              ),
            ],
          ),
        ),
        _Section(
          icon: Icons.flag_outlined,
          title: 'Prioridades diárias',
          empty: s.prioritiesSet == 0,
          child: StatRow(
            tiles: [
              StatTile(value: '${s.prioritiesSet}', label: 'Definidas'),
              StatTile(
                value: '${s.prioritiesDone}',
                label: 'Concluídas',
                color: AppColors.success,
              ),
              StatTile(
                value: s.prioritiesSet == 0
                    ? '—'
                    : _pct(s.prioritiesDone / s.prioritiesSet),
                label: 'Cumprimento',
              ),
            ],
          ),
        ),
        _Section(
          icon: Icons.repeat,
          title: 'Hábitos',
          empty: s.habitConstancy == null,
          child: StatRow(
            tiles: [
              StatTile(value: '${s.habitChecks}', label: 'Marcações'),
              StatTile(
                value: s.habitConstancy == null ? '—' : _pct(s.habitConstancy!),
                label: 'Das metas semanais',
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        _Section(
          icon: Icons.emoji_events_outlined,
          title: 'Desafios',
          empty: s.challengeCheckins == 0 && s.challengesCompleted == 0,
          child: StatRow(
            tiles: [
              StatTile(value: '${s.challengeCheckins}', label: 'Registros'),
              StatTile(
                value: '${s.challengesCompleted}',
                label: 'Concluídos',
                color: AppColors.success,
              ),
            ],
          ),
        ),
        _Section(
          icon: Icons.psychology_outlined,
          title: 'Conhecimentos',
          empty: s.knowledgeTotal == 0,
          child: Column(
            children: [
              StatRow(
                tiles: [
                  StatTile(value: '${s.knowledgeTotal}', label: 'Cadastrados'),
                  StatTile(value: '${s.knowledgeRated}', label: 'Avaliados'),
                  StatTile(
                    value: s.knowledgeAverage == null
                        ? '—'
                        : s.knowledgeAverage!
                              .toStringAsFixed(1)
                              .replaceAll('.', ','),
                    label: 'Média de estrelas',
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (s.knowledgeRated > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SimpleBarChart(
                      height: 80,
                      bars: [
                        for (var i = 0; i < 5; i++)
                          BarData('${i + 1}★', [
                            (s.starsHistogram[i].toDouble(), AppColors.primary),
                          ]),
                      ],
                    ),
                  ),
                ),
              const _Note(
                'Conhecimentos não têm data de avaliação: o total vale para hoje.',
              ),
            ],
          ),
        ),
        _Section(
          icon: Icons.fitness_center,
          title: 'Treinos e peso corporal',
          empty: s.loadChanges == 0 && s.weightEntries == 0,
          child: StatRow(
            tiles: [
              StatTile(value: '${s.loadChanges}', label: 'Ajustes de carga'),
              StatTile(value: '${s.weightEntries}', label: 'Pesagens'),
              StatTile(
                value: s.weightChange == null
                    ? '—'
                    : '${s.weightChange! > 0 ? '+' : ''}${formatNumber(double.parse(s.weightChange!.toStringAsFixed(1)))} kg',
                label: 'Variação do peso',
              ),
            ],
          ),
        ),
        _Section(
          icon: Icons.menu_book_outlined,
          title: 'Leitura e entretenimento',
          empty: s.bibleChapters == 0 && s.mediaWatched == 0,
          child: StatRow(
            tiles: [
              StatTile(
                value: '${s.bibleChapters}',
                label: 'Capítulos da Bíblia',
              ),
              StatTile(value: '${s.mediaWatched}', label: 'Títulos assistidos'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.empty,
    required this.child,
  });

  final IconData icon;
  final String title;
  final bool empty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        if (empty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              'Sem dados neste período.',
              style: TextStyle(color: AppColors.textFaint),
            ),
          )
        else
          child,
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
    ),
  );
}
