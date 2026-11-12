import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/dates.dart';

class GoalsRepository {
  GoalsRepository(this._db);
  final AppDatabase _db;

  Stream<List<Goal>> watchAll() => (_db.select(
    _db.goals,
  )..orderBy([(g) => OrderingTerm.asc(g.createdAt)])).watch();

  Future<void> save({
    int? id,
    required String title,
    required double current,
    required double target,
    String? unit,
    DateTime? deadline,
  }) async {
    final data = GoalsCompanion(
      title: Value(title),
      currentValue: Value(current),
      targetValue: Value(target),
      unit: Value(unit),
      deadline: Value(deadline == null ? null : dateOnly(deadline)),
    );
    if (id == null) {
      await _db.into(_db.goals).insert(data);
    } else {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(data);
    }
  }

  Future<void> setCurrent(int id, double value) =>
      (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(currentValue: Value(value)),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
}

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(databaseProvider)),
);

final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchAll(),
);
