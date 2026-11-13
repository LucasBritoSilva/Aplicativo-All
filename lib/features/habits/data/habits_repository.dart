import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/dates.dart';

class HabitsRepository {
  HabitsRepository(this._db);
  final AppDatabase _db;

  Stream<List<Habit>> watchHabits() => (_db.select(
    _db.habits,
  )..orderBy([(h) => OrderingTerm.asc(h.createdAt)])).watch();

  /// Marcações da semana que começa em [weekStart].
  Stream<List<HabitCheck>> watchWeekChecks(DateTime weekStart) {
    final end = addDays(weekStart, 7);
    return (_db.select(_db.habitChecks)..where(
          (c) =>
              c.day.isBiggerOrEqualValue(weekStart) &
              c.day.isSmallerThanValue(end),
        ))
        .watch();
  }

  Future<void> save({
    int? id,
    required String name,
    required int target,
  }) async {
    final data = HabitsCompanion(
      name: Value(name),
      weeklyTarget: Value(target),
    );
    if (id == null) {
      await _db.into(_db.habits).insert(data);
    } else {
      await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(data);
    }
  }

  /// Marca ou desmarca o hábito no dia [day].
  Future<void> toggle(int habitId, DateTime day) async {
    final d = dateOnly(day);
    await _db.transaction(() async {
      final deleted = await (_db.delete(
        _db.habitChecks,
      )..where((c) => c.habitId.equals(habitId) & c.day.equals(d))).go();
      if (deleted == 0) {
        await _db
            .into(_db.habitChecks)
            .insert(HabitChecksCompanion.insert(habitId: habitId, day: d));
      }
    });
  }

  /// Exclui o hábito e (em cascata) suas marcações.
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.habitChecks,
      )..where((c) => c.habitId.equals(id))).go();
      await (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();
    });
  }
}

final habitsRepositoryProvider = Provider<HabitsRepository>(
  (ref) => HabitsRepository(ref.watch(databaseProvider)),
);

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitsRepositoryProvider).watchHabits(),
);

/// Marcações da semana (chave: segunda-feira da semana).
final weekChecksProvider = StreamProvider.family<List<HabitCheck>, DateTime>(
  (ref, weekStart) =>
      ref.watch(habitsRepositoryProvider).watchWeekChecks(weekStart),
);
