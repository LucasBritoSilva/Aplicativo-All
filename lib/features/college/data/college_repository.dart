import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/grades_logic.dart';

class SubjectView {
  const SubjectView(this.subject, this.assessments);

  final Subject subject;
  final List<Assessment> assessments;

  SubjectResult get result => computeSubject(
    rule: subject.rule,
    minAverage: subject.minAverage,
    maxGrade: subject.maxGrade,
    assessments: [
      for (final a in assessments) (weight: a.weight, grade: a.grade),
    ],
  );
}

class SemesterView {
  const SemesterView(this.semester, this.subjects);

  final Semester semester;
  final List<SubjectView> subjects;
}

/// Prova (avaliação do tipo prova) com a disciplina e os tópicos.
class ExamView {
  const ExamView(this.exam, this.subject, this.topics);

  final Assessment exam;
  final Subject subject;
  final List<ExamTopic> topics;

  int get topicsDone => topics.where((t) => t.done).length;

  double get progress => reviewProgress(topicsDone, topics.length);
}

class CollegeData {
  const CollegeData(this.semesters, this.topics);

  final List<SemesterView> semesters;
  final List<ExamTopic> topics;

  List<SubjectView> get allSubjects => [
    for (final s in semesters) ...s.subjects,
  ];

  List<ExamView> get exams => [
    for (final s in allSubjects)
      for (final a in s.assessments)
        if (a.kind == AssessmentKind.exam)
          ExamView(a, s.subject, [
            for (final t in topics)
              if (t.assessmentId == a.id) t,
          ]),
  ];
}

/// Faculdade: semestres, disciplinas, avaliações e tópicos de revisão.
///
/// Controle de notas e Controle de provas usam estes mesmos dados: uma
/// prova cadastrada em qualquer um dos dois é a mesma avaliação, com a
/// mesma nota, sem lançamento duplicado.
class CollegeRepository {
  CollegeRepository(this._db);
  final AppDatabase _db;

  Future<CollegeData> _load() async {
    final semesters = await (_db.select(
      _db.semesters,
    )..orderBy([(s) => OrderingTerm.desc(s.createdAt)])).get();
    final subjects =
        await (_db.select(_db.subjects)..orderBy([
              (s) => OrderingTerm.asc(s.name.collate(Collate.noCase)),
            ]))
            .get();
    final assessments =
        await (_db.select(_db.assessments)..orderBy([
              (a) => OrderingTerm.asc(a.day),
              (a) => OrderingTerm.asc(a.id),
            ]))
            .get();
    final topics = await (_db.select(
      _db.examTopics,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    return CollegeData([
      for (final sem in semesters)
        SemesterView(sem, [
          for (final sub in subjects)
            if (sub.semesterId == sem.id)
              SubjectView(sub, [
                for (final a in assessments)
                  if (a.subjectId == sub.id) a,
              ]),
        ]),
    ], topics);
  }

  Stream<CollegeData> watch() => _db.watchTables({
    _db.semesters,
    _db.subjects,
    _db.assessments,
    _db.examTopics,
  }, _load);

  Future<int> saveSemester({int? id, required String name}) async {
    if (id == null) {
      return _db
          .into(_db.semesters)
          .insert(SemestersCompanion.insert(name: name));
    }
    await (_db.update(_db.semesters)..where((s) => s.id.equals(id))).write(
      SemestersCompanion(name: Value(name)),
    );
    return id;
  }

  Future<void> deleteSemester(int id) =>
      (_db.delete(_db.semesters)..where((s) => s.id.equals(id))).go();

  Future<int> saveSubject({
    int? id,
    required int semesterId,
    required String name,
    required double minAverage,
    required double maxGrade,
    required AverageRule rule,
  }) async {
    final data = SubjectsCompanion(
      semesterId: Value(semesterId),
      name: Value(name),
      minAverage: Value(minAverage),
      maxGrade: Value(maxGrade),
      rule: Value(rule),
    );
    if (id == null) return _db.into(_db.subjects).insert(data);
    await (_db.update(_db.subjects)..where((s) => s.id.equals(id))).write(data);
    return id;
  }

  Future<void> deleteSubject(int id) =>
      (_db.delete(_db.subjects)..where((s) => s.id.equals(id))).go();

  Future<int> saveAssessment({
    int? id,
    required int subjectId,
    required String title,
    required AssessmentKind kind,
    required double weight,
    double? grade,
    int? day,
    int? startMinute,
    String? content,
    bool? taken,
  }) async {
    final data = AssessmentsCompanion(
      subjectId: Value(subjectId),
      title: Value(title),
      kind: Value(kind),
      weight: Value(weight),
      grade: Value(grade),
      day: Value(day),
      startMinute: Value(startMinute),
      content: Value(content),
      // Ter nota significa que já foi realizada.
      taken: taken == null && grade == null
          ? const Value.absent()
          : Value(grade != null || (taken ?? false)),
    );
    if (id == null) return _db.into(_db.assessments).insert(data);
    await (_db.update(
      _db.assessments,
    )..where((a) => a.id.equals(id))).write(data);
    return id;
  }

  Future<void> setGrade(int id, double? grade) =>
      (_db.update(_db.assessments)..where((a) => a.id.equals(id))).write(
        AssessmentsCompanion(
          grade: Value(grade),
          taken: grade == null ? const Value.absent() : const Value(true),
        ),
      );

  Future<void> setTaken(int id, bool taken) =>
      (_db.update(_db.assessments)..where((a) => a.id.equals(id))).write(
        AssessmentsCompanion(taken: Value(taken)),
      );

  Future<void> deleteAssessment(int id) =>
      (_db.delete(_db.assessments)..where((a) => a.id.equals(id))).go();

  Future<void> addTopic(int assessmentId, String title) => _db
      .into(_db.examTopics)
      .insert(
        ExamTopicsCompanion.insert(assessmentId: assessmentId, title: title),
      );

  Future<void> setTopicDone(int id, bool done) =>
      (_db.update(_db.examTopics)..where((t) => t.id.equals(id))).write(
        ExamTopicsCompanion(done: Value(done)),
      );

  Future<void> deleteTopic(int id) =>
      (_db.delete(_db.examTopics)..where((t) => t.id.equals(id))).go();
}

final collegeRepositoryProvider = Provider<CollegeRepository>(
  (ref) => CollegeRepository(ref.watch(databaseProvider)),
);

final collegeProvider = StreamProvider<CollegeData>(
  (ref) => ref.watch(collegeRepositoryProvider).watch(),
);
