import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/challenges_repository.dart';

/// Desafios pessoais com duração ou quantidade alvo.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final today = epochDay(ref.watch(todayProvider));
    final all = ref.watch(challengesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Desafios pessoais')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo desafio',
        onPressed: () => openChallengeForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          FilterBar<bool>(
            options: const [(false, 'Em andamento'), (true, 'Concluídos')],
            selected: _showCompleted,
            onSelected: (v) => setState(() => _showCompleted = v),
          ),
          Expanded(
            child: all.view((list) {
              final shown = [
                for (final c in list)
                  if ((c.challenge.completedAt != null) == _showCompleted) c,
              ];
              if (shown.isEmpty) {
                return EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: _showCompleted
                      ? 'Nenhum desafio concluído ainda'
                      : 'Nenhum desafio em andamento',
                  message: _showCompleted
                      ? null
                      : 'Crie um desafio por dias (ex.: 30 dias sem açúcar) '
                            'ou por quantidade (ex.: ler 500 páginas).',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _ChallengeCard(view: shown[i], today: today),
              );
            }),
          ),
        ],
      ),
    );
  }
}

Future<void> openChallengeForm(
  BuildContext context,
  WidgetRef ref, [
  Challenge? c,
]) async {
  final r = await showQuickForm(
    context,
    title: c == null ? 'Novo desafio' : 'Editar desafio',
    deleteLabel: c == null ? null : 'Excluir desafio',
    fields: [
      TextSpec(
        'title',
        'Desafio',
        initial: c?.title,
        required: true,
        autofocus: c == null,
      ),
      TextSpec(
        'description',
        'Descrição (opcional)',
        initial: c?.description,
        lines: 3,
      ),
      ChoiceSpec<ChallengeMode>(
        'mode',
        'Como medir',
        options: [for (final m in ChallengeMode.values) (m, m.label)],
        initial: c?.mode ?? ChallengeMode.days,
      ),
      NumberSpec(
        'target',
        'Alvo (número de dias ou quantidade)',
        initial: c?.target.toDouble(),
        required: true,
        decimal: false,
        min: 1,
        max: 100000,
      ),
      TextSpec(
        'unit',
        'Unidade, no modo quantidade (ex.: páginas)',
        initial: c?.unit,
        capitalization: TextCapitalization.none,
      ),
      DateSpec(
        'start',
        'Início',
        initial: c == null ? DateTime.now() : dateFromEpochDay(c.startDay),
        required: true,
      ),
    ],
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(challengesRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir desafio',
      message: '"${c!.title}" e todos os registros serão apagados.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.delete(c.id);
    return;
  }
  final mode = r.choice<ChallengeMode>('mode');
  await repo.save(
    id: c?.id,
    title: r.text('title'),
    description: r.textOrNull('description'),
    mode: mode,
    target: r.integer('target')!,
    unit: mode == ChallengeMode.count ? r.textOrNull('unit') : null,
    startDay: epochDay(r.date('start')!),
  );
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.view, required this.today});

  final ChallengeView view;
  final int today;

  String _value(int v) {
    final c = view.challenge;
    if (c.mode == ChallengeMode.days) return v == 1 ? '1 dia' : '$v dias';
    return '$v${c.unit == null ? '' : ' ${c.unit}'}';
  }

  Future<void> _logAmount(BuildContext context, WidgetRef ref) async {
    final current = view.amountOn(today);
    final r = await showQuickForm(
      context,
      title: 'Registro de hoje',
      fields: [
        NumberSpec(
          'amount',
          'Quantidade${view.challenge.unit == null ? '' : ' (${view.challenge.unit})'}',
          initial: current == 0 ? null : current.toDouble(),
          decimal: false,
          min: 0,
          max: 100000,
        ),
      ],
    );
    if (r == null) return;
    await ref
        .read(challengesRepositoryProvider)
        .setCheckin(view.challenge.id, today, r.integer('amount') ?? 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = view.challenge;
    final p = view.progress(today);
    final repo = ref.read(challengesRepositoryProvider);
    final checkedToday = view.amountOn(today) > 0;
    final started = today >= c.startDay;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openChallengeForm(context, ref, c),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (c.completedAt != null)
                    const Pill(
                      'Concluído',
                      color: AppColors.success,
                      icon: Icons.emoji_events,
                    ),
                ],
              ),
              if (c.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  c.description!,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 12),
              ProgressBar(value: p.fraction, height: 8),
              const SizedBox(height: 8),
              Text(
                '${_value(p.value)} de ${_value(p.target)} · ${p.percent}%',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Sequência atual: ${p.streak} ${p.streak == 1 ? 'dia' : 'dias'}'
                ' · melhor: ${p.bestStreak}',
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 13,
                ),
              ),
              if (!started)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Começa em ${formatDate(dateFromEpochDay(c.startDay))}',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                )
              else if (c.completedAt == null) ...[
                const SizedBox(height: 12),
                if (c.mode == ChallengeMode.days)
                  checkedToday
                      ? OutlinedButton.icon(
                          onPressed: () => repo.setCheckin(c.id, today, 0),
                          icon: const Icon(Icons.undo),
                          label: const Text('Desfazer o registro de hoje'),
                        )
                      : FilledButton.icon(
                          onPressed: () => repo.setCheckin(c.id, today, 1),
                          icon: const Icon(Icons.check),
                          label: const Text('Registrar hoje'),
                        )
                else
                  FilledButton.icon(
                    onPressed: () => _logAmount(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(
                      checkedToday
                          ? 'Hoje: ${_value(view.amountOn(today))} (alterar)'
                          : 'Registrar a quantidade de hoje',
                    ),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Concluído em ${formatDate(c.completedAt!)}',
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
