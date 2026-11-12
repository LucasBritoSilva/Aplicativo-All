import 'package:drift/drift.dart';

/// Regra de cálculo da média de uma disciplina.
enum AverageRule {
  simple('Média simples'),
  weighted('Média ponderada');

  const AverageRule(this.label);
  final String label;
}

/// Tipo de avaliação.
enum AssessmentKind {
  exam('Prova'),
  work('Trabalho'),
  other('Outra');

  const AssessmentKind(this.label);
  final String label;
}

/// Semestres da faculdade.
class Semesters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Disciplinas de um semestre.
class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get semesterId =>
      integer().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// Média mínima para aprovação.
  RealColumn get minAverage => real().withDefault(const Constant(6))();

  /// Nota máxima de cada avaliação (escala da disciplina).
  RealColumn get maxGrade => real().withDefault(const Constant(10))();
  TextColumn get rule => textEnum<AverageRule>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Avaliações de uma disciplina.
///
/// As provas do módulo "Controle de provas" são as avaliações do tipo
/// [AssessmentKind.exam] desta mesma tabela: a nota lançada lá é a mesma
/// usada aqui, sem lançamento duplicado.
class Assessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get kind => textEnum<AssessmentKind>()();

  /// Peso na média ponderada (ignorado na média simples).
  RealColumn get weight => real().withDefault(const Constant(1))();

  /// Nota obtida; nulo enquanto não foi lançada.
  RealColumn get grade => real().nullable()();
  IntColumn get day => integer().nullable()();
  IntColumn get startMinute => integer().nullable()();

  /// Conteúdo cobrado.
  TextColumn get content => text().nullable()();

  /// Se a avaliação já foi realizada.
  BoolColumn get taken => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tópicos de revisão de uma prova.
class ExamTopics extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assessmentId =>
      integer().references(Assessments, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}
