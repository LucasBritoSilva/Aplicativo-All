import 'package:aplicativo_all/features/college/data/college_tables.dart';
import 'package:aplicativo_all/features/college/domain/grades_logic.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectResult calc(
  AverageRule rule,
  List<GradeInput> items, {
  double min = 6,
  double max = 10,
}) => computeSubject(
  rule: rule,
  minAverage: min,
  maxGrade: max,
  assessments: items,
);

void main() {
  test('sem avaliações não inventa média', () {
    final r = calc(AverageRule.simple, const []);
    expect(r.status, SubjectStatus.noAssessments);
    expect(r.currentAverage, isNull);
  });

  test('média simples com todas as notas: aprovada ou reprovada', () {
    final ok = calc(AverageRule.simple, const [
      (weight: 1, grade: 7),
      (weight: 1, grade: 5),
      (weight: 1, grade: 6),
    ]);
    expect(ok.finalAverage, closeTo(6, 1e-9));
    expect(ok.status, SubjectStatus.approved);

    final bad = calc(AverageRule.simple, const [
      (weight: 1, grade: 5),
      (weight: 1, grade: 6),
    ]);
    expect(bad.finalAverage, closeTo(5.5, 1e-9));
    expect(bad.status, SubjectStatus.failed);
  });

  test('média simples ignora os pesos', () {
    final r = calc(AverageRule.simple, const [
      (weight: 3, grade: 10),
      (weight: 1, grade: 4),
    ]);
    expect(r.finalAverage, closeTo(7, 1e-9));
  });

  test('média ponderada usa os pesos', () {
    final r = calc(AverageRule.weighted, const [
      (weight: 3, grade: 10),
      (weight: 1, grade: 4),
    ]);
    expect(r.finalAverage, closeTo(8.5, 1e-9));
  });

  test('nota necessária na média simples', () {
    // (7 + x + x) / 3 = 6 -> x = 5,5
    final r = calc(AverageRule.simple, const [
      (weight: 1, grade: 7),
      (weight: 1, grade: null),
      (weight: 1, grade: null),
    ]);
    expect(r.status, SubjectStatus.inProgress);
    expect(r.currentAverage, closeTo(7, 1e-9));
    expect(r.neededGrade, closeTo(5.5, 1e-9));
  });

  test('nota necessária na média ponderada', () {
    // (4*2 + x*3) / 5 = 6 -> x = 22/3
    final r = calc(AverageRule.weighted, const [
      (weight: 2, grade: 4),
      (weight: 3, grade: null),
    ]);
    expect(r.neededGrade, closeTo(22 / 3, 1e-9));
  });

  test('aprovação garantida quando já passou da média', () {
    final r = calc(AverageRule.weighted, const [
      (weight: 9, grade: 10),
      (weight: 1, grade: null),
    ]);
    expect(r.approvalGuaranteed, isTrue);
    expect(r.status, SubjectStatus.inProgress);
  });

  test('reprovada quando nem a nota máxima basta', () {
    final r = calc(AverageRule.simple, const [
      (weight: 1, grade: 0),
      (weight: 1, grade: 0),
      (weight: 1, grade: null),
    ]);
    expect(r.impossible, isTrue);
    expect(r.status, SubjectStatus.failed);
    expect(r.neededGrade, closeTo(18, 1e-9));
  });

  test('peso zero na ponderada é apontado em vez de calcular errado', () {
    final r = calc(AverageRule.weighted, const [
      (weight: 0, grade: 8),
      (weight: 1, grade: null),
    ]);
    expect(r.problem, isNotNull);
    expect(r.neededGrade, isNull);
  });

  test('escala diferente de 0 a 10', () {
    final r = calc(
      AverageRule.simple,
      const [(weight: 1, grade: 50), (weight: 1, grade: null)],
      min: 60,
      max: 100,
    );
    expect(r.neededGrade, closeTo(70, 1e-9));
    expect(r.impossible, isFalse);
  });

  test('progresso da revisão', () {
    expect(reviewProgress(0, 0), 0);
    expect(reviewProgress(2, 4), 0.5);
  });
}
