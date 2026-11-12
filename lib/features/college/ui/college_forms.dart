import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/college_repository.dart';

String grade(double v) => formatNumber(double.parse(v.toStringAsFixed(2)));

Future<void> openSemesterForm(
  BuildContext context,
  WidgetRef ref, [
  Semester? s,
]) async {
  final r = await showQuickForm(
    context,
    title: s == null ? 'Novo semestre' : 'Editar semestre',
    deleteLabel: s == null ? null : 'Excluir semestre',
    fields: [
      TextSpec(
        'name',
        'Nome (ex.: 2026.2)',
        initial: s?.name,
        required: true,
        autofocus: s == null,
      ),
    ],
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(collegeRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir semestre',
      message:
          'O semestre "${s!.name}", as disciplinas, avaliações e notas '
          'dele serão apagados.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteSemester(s.id);
    return;
  }
  await repo.saveSemester(id: s?.id, name: r.text('name'));
}

/// Cadastro de disciplina. Sem semestres, pede o nome de um novo.
Future<void> openSubjectForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Semester> semesters,
  Subject? subject,
  int? semesterId,
}) async {
  final s = subject;
  final r = await showQuickForm(
    context,
    title: s == null ? 'Nova disciplina' : 'Editar disciplina',
    deleteLabel: s == null ? null : 'Excluir disciplina',
    fields: [
      TextSpec(
        'name',
        'Disciplina',
        initial: s?.name,
        required: true,
        autofocus: s == null,
      ),
      if (semesters.isEmpty)
        const TextSpec('semesterName', 'Semestre (ex.: 2026.2)', required: true)
      else
        ChoiceSpec<int>(
          'semester',
          'Semestre',
          options: [for (final x in semesters) (x.id, x.name)],
          initial: s?.semesterId ?? semesterId ?? semesters.first.id,
        ),
      ChoiceSpec<AverageRule>(
        'rule',
        'Cálculo da média',
        options: [for (final x in AverageRule.values) (x, x.label)],
        initial: s?.rule ?? AverageRule.simple,
      ),
      NumberSpec(
        'min',
        'Média mínima para aprovação',
        initial: s?.minAverage ?? 6,
        required: true,
        min: 0,
      ),
      NumberSpec(
        'max',
        'Nota máxima de cada avaliação',
        initial: s?.maxGrade ?? 10,
        required: true,
        min: 0.01,
      ),
    ],
    validate: (v) => v.number('min')! > v.number('max')!
        ? 'A média mínima não pode passar da nota máxima.'
        : null,
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(collegeRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir disciplina',
      message:
          '"${s!.name}" e todas as avaliações e notas dela serão apagadas.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteSubject(s.id);
    return;
  }
  final semId = semesters.isEmpty
      ? await repo.saveSemester(name: r.text('semesterName'))
      : r.choice<int>('semester');
  await repo.saveSubject(
    id: s?.id,
    semesterId: semId,
    name: r.text('name'),
    minAverage: r.number('min')!,
    maxGrade: r.number('max')!,
    rule: r.choice<AverageRule>('rule'),
  );
}

/// Cadastro de avaliação (também usado para as provas).
Future<void> openAssessmentForm(
  BuildContext context,
  WidgetRef ref, {
  required List<SubjectView> subjects,
  Assessment? assessment,
  int? subjectId,
  AssessmentKind? kind,
}) async {
  final a = assessment;
  if (subjects.isEmpty) {
    showMessage(context, 'Cadastre uma disciplina primeiro.');
    return;
  }
  final chosenSubjectId =
      a?.subjectId ?? subjectId ?? subjects.first.subject.id;
  final subject = subjects
      .firstWhere(
        (s) => s.subject.id == chosenSubjectId,
        orElse: () => subjects.first,
      )
      .subject;
  final r = await showQuickForm(
    context,
    title: a == null
        ? (kind == AssessmentKind.exam ? 'Nova prova' : 'Nova avaliação')
        : 'Editar avaliação',
    deleteLabel: a == null ? null : 'Excluir avaliação',
    fields: [
      TextSpec(
        'title',
        'Título (ex.: P1, Trabalho final)',
        initial: a?.title,
        required: true,
        autofocus: a == null,
      ),
      ChoiceSpec<int>(
        'subject',
        'Disciplina',
        options: [for (final s in subjects) (s.subject.id, s.subject.name)],
        initial: subject.id,
      ),
      ChoiceSpec<AssessmentKind>(
        'kind',
        'Tipo',
        options: [for (final k in AssessmentKind.values) (k, k.label)],
        initial: a?.kind ?? kind ?? AssessmentKind.exam,
      ),
      NumberSpec(
        'weight',
        'Peso (usado na média ponderada)',
        initial: a?.weight ?? 1,
        required: true,
        min: 0.01,
      ),
      NumberSpec(
        'grade',
        'Nota obtida (deixe vazio se ainda não tem)',
        initial: a?.grade,
        min: 0,
      ),
      DateSpec(
        'day',
        'Data',
        initial: a?.day == null ? null : dateFromEpochDay(a!.day!),
      ),
      TimeSpec('time', 'Horário', initial: a?.startMinute),
      TextSpec('content', 'Conteúdo cobrado', initial: a?.content, lines: 4),
    ],
    validate: (v) {
      final g = v.number('grade');
      final sub = subjects
          .firstWhere((s) => s.subject.id == v.choice<int>('subject'))
          .subject;
      if (g != null && g > sub.maxGrade) {
        return 'A nota passa do máximo da disciplina (${grade(sub.maxGrade)}).';
      }
      return null;
    },
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(collegeRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir avaliação',
      message: '"${a!.title}", a nota e os tópicos de revisão serão apagados.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteAssessment(a.id);
    return;
  }
  final day = r.date('day');
  await repo.saveAssessment(
    id: a?.id,
    subjectId: r.choice<int>('subject'),
    title: r.text('title'),
    kind: r.choice<AssessmentKind>('kind'),
    weight: r.number('weight')!,
    grade: r.number('grade'),
    day: day == null ? null : epochDay(day),
    startMinute: r.time('time'),
    content: r.textOrNull('content'),
  );
}

/// Lançar ou apagar a nota de uma avaliação.
Future<void> openGradeDialog(
  BuildContext context,
  WidgetRef ref,
  Assessment a,
  Subject subject,
) async {
  final r = await showQuickForm(
    context,
    title: 'Nota: ${a.title}',
    fields: [
      NumberSpec(
        'grade',
        'Nota (vazio para apagar)',
        initial: a.grade,
        min: 0,
        max: subject.maxGrade,
      ),
    ],
  );
  if (r == null) return;
  await ref.read(collegeRepositoryProvider).setGrade(a.id, r.number('grade'));
}
