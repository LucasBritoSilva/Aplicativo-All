/// Cálculo das médias da faculdade. Nada é inventado: sem nota lançada não
/// há média, e a nota necessária só aparece quando dá para calcular.
library;

import '../data/college_tables.dart';

/// Uma avaliação para o cálculo: peso e nota (nula = ainda sem nota).
typedef GradeInput = ({double weight, double? grade});

enum SubjectStatus {
  noAssessments('Sem avaliações'),
  inProgress('Em andamento'),
  approved('Aprovada'),
  failed('Reprovada');

  const SubjectStatus(this.label);
  final String label;
}

class SubjectResult {
  const SubjectResult({
    required this.status,
    this.currentAverage,
    this.finalAverage,
    this.neededGrade,
    this.approvalGuaranteed = false,
    this.impossible = false,
    this.problem,
  });

  final SubjectStatus status;

  /// Média só das avaliações que já têm nota.
  final double? currentAverage;

  /// Média final (todas as avaliações com nota).
  final double? finalAverage;

  /// Nota mínima, igual em cada avaliação restante, para atingir a média.
  final double? neededGrade;

  /// Já atingiu a média mesmo tirando zero no que falta.
  final bool approvalGuaranteed;

  /// Nem com a nota máxima no que falta atinge a média.
  final bool impossible;

  /// Explica por que não deu para calcular (por exemplo, pesos zerados).
  final String? problem;
}

double? _average(AverageRule rule, Iterable<GradeInput> graded) {
  final list = graded.where((a) => a.grade != null).toList();
  if (list.isEmpty) return null;
  if (rule == AverageRule.simple) {
    return list.fold<double>(0, (s, a) => s + a.grade!) / list.length;
  }
  final weights = list.fold<double>(0, (s, a) => s + a.weight);
  if (weights <= 0) return null;
  return list.fold<double>(0, (s, a) => s + a.grade! * a.weight) / weights;
}

SubjectResult computeSubject({
  required AverageRule rule,
  required double minAverage,
  required double maxGrade,
  required List<GradeInput> assessments,
}) {
  if (assessments.isEmpty) {
    return const SubjectResult(status: SubjectStatus.noAssessments);
  }
  if (rule == AverageRule.weighted && assessments.any((a) => a.weight <= 0)) {
    return const SubjectResult(
      status: SubjectStatus.inProgress,
      problem: 'Há avaliação com peso zero ou negativo. Corrija os pesos.',
    );
  }

  final graded = assessments.where((a) => a.grade != null).toList();
  final pending = assessments.where((a) => a.grade == null).toList();
  final current = _average(rule, graded);

  if (pending.isEmpty) {
    final finalAvg = current!;
    return SubjectResult(
      status: finalAvg + 1e-9 >= minAverage
          ? SubjectStatus.approved
          : SubjectStatus.failed,
      currentAverage: finalAvg,
      finalAverage: finalAvg,
    );
  }

  // Nota x igual em todas as avaliações restantes para fechar a média.
  final double needed;
  if (rule == AverageRule.simple) {
    final sum = graded.fold<double>(0, (s, a) => s + a.grade!);
    needed = (minAverage * assessments.length - sum) / pending.length;
  } else {
    final totalWeight = assessments.fold<double>(0, (s, a) => s + a.weight);
    final gradedPoints = graded.fold<double>(
      0,
      (s, a) => s + a.grade! * a.weight,
    );
    final pendingWeight = pending.fold<double>(0, (s, a) => s + a.weight);
    needed = (minAverage * totalWeight - gradedPoints) / pendingWeight;
  }

  if (needed <= 0) {
    return SubjectResult(
      status: SubjectStatus.inProgress,
      currentAverage: current,
      neededGrade: 0,
      approvalGuaranteed: true,
    );
  }
  if (needed > maxGrade + 1e-9) {
    return SubjectResult(
      status: SubjectStatus.failed,
      currentAverage: current,
      neededGrade: needed,
      impossible: true,
    );
  }
  return SubjectResult(
    status: SubjectStatus.inProgress,
    currentAverage: current,
    neededGrade: needed,
  );
}

/// Fração da revisão concluída (tópicos marcados / total).
double reviewProgress(int done, int total) => total == 0 ? 0 : done / total;
