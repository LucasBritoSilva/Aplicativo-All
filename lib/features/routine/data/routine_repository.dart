import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/dates.dart';
import '../domain/routine_logic.dart';

class RoutineRepository {
  RoutineRepository(this._db);
  final AppDatabase _db;

  Stream<List<RoutineItem>> watchAll() =>
      (_db.select(_db.routineItems)..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  Future<void> add(String title) async {
    final maxPos = _db.routineItems.position.max();
    final row = await (_db.selectOnly(
      _db.routineItems,
    )..addColumns([maxPos])).getSingle();
    final next = (row.read(maxPos) ?? -1) + 1;
    await _db
        .into(_db.routineItems)
        .insert(
          RoutineItemsCompanion.insert(title: title, position: Value(next)),
        );
  }

  Future<void> rename(int id, String title) =>
      (_db.update(_db.routineItems)..where((t) => t.id.equals(id))).write(
        RoutineItemsCompanion(title: Value(title)),
      );

  Future<void> setDone(int id, {required bool done, required DateTime today}) =>
      (_db.update(_db.routineItems)..where((t) => t.id.equals(id))).write(
        RoutineItemsCompanion(doneOn: Value(done ? dateOnly(today) : null)),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.routineItems)..where((t) => t.id.equals(id))).go();

  /// Reset diário: desmarca tudo o que foi marcado em dias anteriores.
  Future<int> resetStale(DateTime today) async {
    final items = await _db.select(_db.routineItems).get();
    final ids = routineItemsToReset(
      items.map((i) => (id: i.id, doneOn: i.doneOn)),
      today,
    );
    if (ids.isEmpty) return 0;
    return (_db.update(_db.routineItems)..where((t) => t.id.isIn(ids))).write(
      const RoutineItemsCompanion(doneOn: Value(null)),
    );
  }
}

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(ref.watch(databaseProvider)),
);

final routineItemsProvider = StreamProvider<List<RoutineItem>>(
  (ref) => ref.watch(routineRepositoryProvider).watchAll(),
);
