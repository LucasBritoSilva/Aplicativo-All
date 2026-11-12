import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/college_repository.dart';
import '../domain/grades_logic.dart';
import 'college_forms.dart';

Color subjectStatusColor(SubjectStatus s) => switch (s) {
  SubjectStatus.approved => AppColors.success,
  SubjectStatus.failed => AppColors.danger,
  SubjectStatus.inProgress => AppColors.primary,
  SubjectStatus.noAssessments => AppColors.textMuted,
};

/// Frase que resume a situação de uma disciplina.
String describeResult(SubjectResult r, Subject s) {
  if (r.problem != null) return r.problem!;
  if (r.status == SubjectStatus.noAssessments) {
    return 'Cadastre as avaliações para calcular a média.';
  }
  if (r.finalAverage != null) {
    return 'Média final ${grade(r.finalAverage!)} (mínimo ${grade(s.minAverage)}).';
  }
  final current = r.currentAverage == null
      ? 'Nenhuma nota lançada ainda.'
      : 'Média atual ${grade(r.currentAverage!)}.';
  if (r.approvalGuaranteed) return '$current Aprovação garantida.';
  if (r.impossible) {
    return '$current Precisaria de ${grade(r.neededGrade!)} em cada avaliação '
        'restante (máximo ${grade(s.maxGrade)}).';
  }
  if (r.neededGrade != null) {
    return '$current Precisa de ${grade(r.neededGrade!)} em cada avaliação restante.';
  }
  return current;
}

/// Controle de notas: semestres, disciplinas, avaliações e médias.
class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(collegeProvider);
    final semesters = [
      for (final s in data.value?.semesters ?? const <SemesterView>[])
        s.semester,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de notas'),
        actions: [
          IconButton(
            tooltip: 'Novo semestre',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => openSemesterForm(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openSubjectForm(context, ref, semesters: semesters),
        icon: const Icon(Icons.add),
        label: const Text('Disciplina'),
      ),
      body: data.view((d) {
        if (d.allSubjects.isEmpty && d.semesters.isEmpty) {
          return const EmptyState(
            icon: Icons.school_outlined,
            title: 'Nenhuma disciplina',
            message:
                'Cadastre as disciplinas do semestre com a média mínima e a '
                'forma de cálculo (simples ou ponderada).',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            for (final sem in d.semesters) ...[
              SectionLabel(
                sem.semester.name,
                padding: const EdgeInsets.fromLTRB(4, 16, 0, 6),
                trailing: IconButton(
                  tooltip: 'Editar semestre',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => openSemesterForm(context, ref, sem.semester),
                ),
              ),
              if (sem.subjects.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Nenhuma disciplina neste semestre.',
                    style: TextStyle(color: AppColors.textFaint),
                  ),
                ),
              for (final sub in sem.subjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SubjectCard(view: sub),
                ),
            ],
          ],
        );
      }),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.view});

  final SubjectView view;

  @override
  Widget build(BuildContext context) {
    final r = view.result;
    final s = view.subject;
    final avg = r.finalAverage ?? r.currentAverage;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SubjectScreen(subjectId: s.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Pill(r.status.label, color: subjectStatusColor(r.status)),
                    const SizedBox(height: 6),
                    Text(
                      describeResult(r, s),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                avg == null ? '—' : grade(avg),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: subjectStatusColor(r.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalhe da disciplina: avaliações, pesos, notas e situação.
class SubjectScreen extends ConsumerWidget {
  const SubjectScreen({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(collegeProvider);
    return data.view((d) {
      final view = d.allSubjects
          .where((s) => s.subject.id == subjectId)
          .firstOrNull;
      if (view == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
            icon: Icons.school_outlined,
            title: 'Disciplina excluída',
          ),
        );
      }
      final s = view.subject;
      final r = view.result;
      final semesters = [for (final x in d.semesters) x.semester];
      return Scaffold(
        appBar: AppBar(
          title: Text(s.name),
          actions: [
            IconButton(
              tooltip: 'Editar disciplina',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openSubjectForm(
                context,
                ref,
                semesters: semesters,
                subject: s,
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openAssessmentForm(
            context,
            ref,
            subjects: d.allSubjects,
            subjectId: s.id,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Avaliação'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Pill(
                          r.status.label,
                          color: subjectStatusColor(r.status),
                        ),
                        const SizedBox(width: 8),
                        Pill(s.rule.label),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(describeResult(r, s)),
                    const SizedBox(height: 6),
                    Text(
                      'Média mínima ${grade(s.minAverage)} · notas de 0 a ${grade(s.maxGrade)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SectionLabel(
              'Avaliações',
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
            ),
            if (view.assessments.isEmpty)
              const Text(
                'Nenhuma avaliação cadastrada.',
                style: TextStyle(color: AppColors.textFaint),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final a in view.assessments)
                      ListTile(
                        onTap: () => openAssessmentForm(
                          context,
                          ref,
                          subjects: d.allSubjects,
                          assessment: a,
                        ),
                        title: Text(a.title),
                        subtitle: Text(
                          [
                            a.kind.label,
                            if (s.rule == AverageRule.weighted)
                              'peso ${grade(a.weight)}',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        trailing: TextButton(
                          onPressed: () => openGradeDialog(context, ref, a, s),
                          child: Text(
                            a.grade == null ? 'Lançar nota' : grade(a.grade!),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}
