import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/college_repository.dart';
import 'college_forms.dart';

/// Controle de provas: data, conteúdo, revisão e nota.
///
/// As provas são as avaliações do tipo "Prova" do Controle de notas: a
/// nota lançada aqui aparece lá, e vice-versa.
class ExamsScreen extends ConsumerStatefulWidget {
  const ExamsScreen({super.key});

  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> {
  bool _taken = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(collegeProvider);
    final todayDate = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Controle de provas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final d = data.value;
          if (d == null) return;
          if (d.allSubjects.isEmpty) {
            openSubjectForm(
              context,
              ref,
              semesters: [for (final s in d.semesters) s.semester],
            );
            showMessage(context, 'Primeiro, cadastre a disciplina da prova.');
            return;
          }
          openAssessmentForm(
            context,
            ref,
            subjects: d.allSubjects,
            kind: AssessmentKind.exam,
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Prova'),
      ),
      body: Column(
        children: [
          FilterBar<bool>(
            options: const [(false, 'Pendentes'), (true, 'Realizadas')],
            selected: _taken,
            onSelected: (v) => setState(() => _taken = v),
          ),
          Expanded(
            child: data.view((d) {
              final exams =
                  [
                    for (final e in d.exams)
                      if (e.exam.taken == _taken) e,
                  ]..sort((a, b) {
                    final ad = a.exam.day ?? 1 << 30,
                        bd = b.exam.day ?? 1 << 30;
                    return _taken ? bd.compareTo(ad) : ad.compareTo(bd);
                  });
              if (exams.isEmpty) {
                return EmptyState(
                  icon: Icons.assignment_outlined,
                  title: _taken
                      ? 'Nenhuma prova realizada'
                      : 'Nenhuma prova pendente',
                  message: _taken ? null : 'Cadastre a prova com data, conteúdo e os tópicos para revisar.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: exams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = exams[i];
                  final day = e.exam.day == null
                      ? null
                      : dateFromEpochDay(e.exam.day!);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamDetailScreen(examId: e.exam.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${e.subject.name} · ${e.exam.title}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                if (e.exam.grade != null)
                                  Pill(
                                    'Nota ${grade(e.exam.grade!)}',
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              day == null
                                  ? 'Sem data'
                                  : '${friendlyDay(day, todayDate)} · ${formatDate(day)}'
                                        '${e.exam.startMinute == null ? '' : ' às ${formatMinute(e.exam.startMinute!)}'}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (e.topics.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ProgressBar(value: e.progress),
                              const SizedBox(height: 4),
                              Text(
                                'Revisão: ${e.topicsDone} de ${e.topics.length} tópicos',
                                style: const TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class ExamDetailScreen extends ConsumerWidget {
  const ExamDetailScreen({super.key, required this.examId});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(collegeProvider);
    final todayDate = ref.watch(todayProvider);
    final repo = ref.read(collegeRepositoryProvider);
    return data.view((d) {
      final e = d.exams.where((x) => x.exam.id == examId).firstOrNull;
      if (e == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Prova excluída',
          ),
        );
      }
      final day = e.exam.day == null ? null : dateFromEpochDay(e.exam.day!);
      return Scaffold(
        appBar: AppBar(
          title: Text(e.exam.title),
          actions: [
            IconButton(
              tooltip: 'Editar prova',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openAssessmentForm(
                context,
                ref,
                subjects: d.allSubjects,
                assessment: e.exam,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.subject.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day == null
                          ? 'Sem data definida'
                          : '${friendlyDay(day, todayDate)} · ${weekdayLong(day)}, ${formatDate(day)}'
                                '${e.exam.startMinute == null ? '' : ' às ${formatMinute(e.exam.startMinute!)}'}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    if (e.exam.content != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Conteúdo cobrado',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(e.exam.content!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Prova realizada'),
              value: e.exam.taken,
              onChanged: (v) => repo.setTaken(e.exam.id, v),
            ),
            ListTile(
              title: const Text('Nota obtida'),
              subtitle: const Text(
                'A mesma nota vale no Controle de notas',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: () =>
                    openGradeDialog(context, ref, e.exam, e.subject),
                child: Text(
                  e.exam.grade == null ? 'Lançar nota' : grade(e.exam.grade!),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            SectionLabel(
              'Revisão (${e.topicsDone}/${e.topics.length})',
              padding: const EdgeInsets.fromLTRB(4, 16, 0, 6),
              trailing: IconButton(
                tooltip: 'Novo tópico',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final r = await showQuickForm(
                    context,
                    title: 'Tópico de revisão',
                    fields: const [
                      TextSpec('t', 'Tópico', required: true, autofocus: true),
                    ],
                  );
                  if (r != null) await repo.addTopic(e.exam.id, r.text('t'));
                },
              ),
            ),
            if (e.topics.isNotEmpty) ...[
              ProgressBar(value: e.progress, height: 8),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final t in e.topics)
                      CheckboxListTile(
                        value: t.done,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => repo.setTopicDone(t.id, v ?? false),
                        title: Text(
                          t.title,
                          style: t.done
                              ? const TextStyle(
                                  color: AppColors.textFaint,
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        secondary: IconButton(
                          tooltip: 'Remover tópico',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => repo.deleteTopic(t.id),
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              const Text(
                'Adicione os tópicos que precisa revisar.',
                style: TextStyle(color: AppColors.textFaint),
              ),
          ],
        ),
      );
    });
  }
}
