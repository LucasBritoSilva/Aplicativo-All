import 'package:drift/drift.dart';

/// Fichas de treino (Treino A, B, C, D...).
class WorkoutSheets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// Exercícios de uma ficha.
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sheetId =>
      integer().references(WorkoutSheets, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get sets => integer()();

  /// Texto livre: "12", "8-10", "até a falha".
  TextColumn get reps => text()();

  /// Carga em kg; nulo para exercícios sem carga.
  RealColumn get load => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// Histórico de cargas: uma linha por dia em que a carga foi alterada.
@DataClassName('ExerciseLoadEntry')
class ExerciseLoadEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get day => integer()();
  RealColumn get load => real()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, day},
  ];
}

/// Registros datados do peso corporal (um por dia).
@DataClassName('BodyWeightEntry')
class BodyWeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get day => integer().unique()();
  RealColumn get weight => real()();
}
