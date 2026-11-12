import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_repository.dart';

class SheetView {
  const SheetView(this.sheet, this.exercises);

  final WorkoutSheet sheet;
  final List<WorkoutExercise> exercises;
}

class GymRepository {
  GymRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  Future<List<SheetView>> _loadSheets() async {
    final sheets =
        await (_db.select(_db.workoutSheets)..orderBy([
              (s) => OrderingTerm.asc(s.position),
              (s) => OrderingTerm.asc(s.id),
            ]))
            .get();
    final exercises =
        await (_db.select(_db.workoutExercises)..orderBy([
              (e) => OrderingTerm.asc(e.position),
              (e) => OrderingTerm.asc(e.id),
            ]))
            .get();
    return [
      for (final s in sheets)
        SheetView(s, [
          for (final e in exercises)
            if (e.sheetId == s.id) e,
        ]),
    ];
  }

  Stream<List<SheetView>> watchSheets() =>
      _db.watchTables({_db.workoutSheets, _db.workoutExercises}, _loadSheets);

  Future<int> saveSheet({int? id, required String name}) async {
    if (id != null) {
      await (_db.update(_db.workoutSheets)..where((s) => s.id.equals(id)))
          .write(WorkoutSheetsCompanion(name: Value(name)));
      return id;
    }
    final count = (await _db.select(_db.workoutSheets).get()).length;
    return _db
        .into(_db.workoutSheets)
        .insert(
          WorkoutSheetsCompanion.insert(name: name, position: Value(count)),
        );
  }

  Future<void> deleteSheet(int id) =>
      (_db.delete(_db.workoutSheets)..where((s) => s.id.equals(id))).go();

  /// Salva o exercício. Quando a carga muda, registra no histórico de
  /// cargas do dia (uma linha por exercício e dia).
  Future<void> saveExercise({
    int? id,
    required int sheetId,
    required String name,
    required int sets,
    required String reps,
    double? load,
    String? notes,
    required int today,
  }) => _db.transaction(() async {
    final data = WorkoutExercisesCompanion(
      sheetId: Value(sheetId),
      name: Value(name),
      sets: Value(sets),
      reps: Value(reps),
      load: Value(load),
      notes: Value(notes),
    );
    var exerciseId = id;
    double? previous;
    if (id == null) {
      final count = (await (_db.select(
        _db.workoutExercises,
      )..where((e) => e.sheetId.equals(sheetId))).get()).length;
      exerciseId = await _db
          .into(_db.workoutExercises)
          .insert(data.copyWith(position: Value(count)));
    } else {
      final old = await (_db.select(
        _db.workoutExercises,
      )..where((e) => e.id.equals(id))).getSingle();
      previous = old.load;
      await (_db.update(
        _db.workoutExercises,
      )..where((e) => e.id.equals(id))).write(data);
    }
    if (load != null && (id == null || load != previous)) {
      await _db
          .into(_db.exerciseLoadEntries)
          .insertOnConflictUpdate(
            ExerciseLoadEntriesCompanion.insert(
              exerciseId: exerciseId!,
              day: today,
              load: load,
            ),
          );
    }
  });

  Future<void> deleteExercise(int id) =>
      (_db.delete(_db.workoutExercises)..where((e) => e.id.equals(id))).go();

  Stream<List<ExerciseLoadEntry>> watchLoads(int exerciseId) =>
      (_db.select(_db.exerciseLoadEntries)
            ..where((e) => e.exerciseId.equals(exerciseId))
            ..orderBy([(e) => OrderingTerm.asc(e.day)]))
          .watch();

  // ---- Peso corporal ----

  Stream<List<BodyWeightEntry>> watchWeights() => (_db.select(
    _db.bodyWeightEntries,
  )..orderBy([(w) => OrderingTerm.asc(w.day)])).watch();

  /// Registra o peso do dia (substitui se já houver registro no dia).
  Future<void> logWeight(int day, double weight) => _db
      .into(_db.bodyWeightEntries)
      .insertOnConflictUpdate(
        BodyWeightEntriesCompanion.insert(day: day, weight: weight),
      );

  Future<void> deleteWeight(int id) =>
      (_db.delete(_db.bodyWeightEntries)..where((w) => w.id.equals(id))).go();

  Future<void> setGoal(double? goal) => goal == null
      ? _settings.remove(SettingKeys.weightGoal)
      : _settings.write(SettingKeys.weightGoal, '$goal');
}

final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => GymRepository(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final sheetsProvider = StreamProvider<List<SheetView>>(
  (ref) => ref.watch(gymRepositoryProvider).watchSheets(),
);

final weightsProvider = StreamProvider<List<BodyWeightEntry>>(
  (ref) => ref.watch(gymRepositoryProvider).watchWeights(),
);

final loadHistoryProvider = StreamProvider.autoDispose
    .family<List<ExerciseLoadEntry>, int>(
      (ref, id) => ref.watch(gymRepositoryProvider).watchLoads(id),
    );

final weightGoalProvider = Provider<double?>((ref) {
  final raw = ref.watch(settingProvider(SettingKeys.weightGoal)).value;
  return raw == null ? null : double.tryParse(raw);
});
