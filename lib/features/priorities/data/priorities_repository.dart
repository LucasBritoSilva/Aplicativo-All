import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

/// Máximo de prioridades por dia.
const maxDailyPriorities = 3;

class PrioritiesFullError implements Exception {
  const PrioritiesFullError();

  @override
  String toString() => 'O dia já tem $maxDailyPriorities prioridades.';
}

/// Ids depois de mover o item da posição [from] para a posição final [to].
List<int> reorderIds(List<int> ids, int from, int to) {
  final list = [...ids];
  final item = list.removeAt(from);
  list.insert(to.clamp(0, list.length), item);
  return list;
}

/// Prioridades do dia. Cada dia tem a sua lista; o histórico fica guardado
/// e começar um novo dia é começar uma lista vazia.
class PrioritiesRepository {
  PrioritiesRepository(this._db);
  final AppDatabase _db;

  Stream<List<DailyPriority>> watchDay(int day) =>
      (_db.select(_db.dailyPriorities)
            ..where((p) => p.day.equals(day))
            ..orderBy([
              (p) => OrderingTerm.asc(p.position),
              (p) => OrderingTerm.asc(p.id),
            ]))
          .watch();

  /// Dias anteriores com prioridades, do mais recente ao mais antigo.
  Stream<List<DailyPriority>> watchHistory(int beforeDay) =>
      (_db.select(_db.dailyPriorities)
            ..where((p) => p.day.isSmallerThanValue(beforeDay))
            ..orderBy([
              (p) => OrderingTerm.desc(p.day),
              (p) => OrderingTerm.asc(p.position),
            ]))
          .watch();

  Future<void> add(int day, String title) => _db.transaction(() async {
    final current = await (_db.select(
      _db.dailyPriorities,
    )..where((p) => p.day.equals(day))).get();
    if (current.length >= maxDailyPriorities) throw const PrioritiesFullError();
    final next = current.fold<int>(
      -1,
      (m, p) => p.position > m ? p.position : m,
    );
    await _db
        .into(_db.dailyPriorities)
        .insert(
          DailyPrioritiesCompanion.insert(
            day: day,
            title: title.trim(),
            position: Value(next + 1),
          ),
        );
  });

  Future<void> rename(int id, String title) =>
      (_db.update(_db.dailyPriorities)..where((p) => p.id.equals(id))).write(
        DailyPrioritiesCompanion(title: Value(title.trim())),
      );

  Future<void> setDone(int id, bool done) =>
      (_db.update(_db.dailyPriorities)..where((p) => p.id.equals(id))).write(
        DailyPrioritiesCompanion(done: Value(done)),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.dailyPriorities)..where((p) => p.id.equals(id))).go();

  /// Grava a nova ordem (ids na ordem desejada).
  Future<void> reorder(List<int> orderedIds) => _db.transaction(() async {
    for (final (i, id) in orderedIds.indexed) {
      await (_db.update(_db.dailyPriorities)..where((p) => p.id.equals(id)))
          .write(DailyPrioritiesCompanion(position: Value(i)));
    }
  });

  /// Copia para [today] as prioridades não concluídas de [fromDay], até o
  /// limite. O dia anterior fica intacto no histórico.
  Future<int> carryOver(int fromDay, int today) => _db.transaction(() async {
    final pending =
        await (_db.select(_db.dailyPriorities)
              ..where((p) => p.day.equals(fromDay) & p.done.equals(false))
              ..orderBy([(p) => OrderingTerm.asc(p.position)]))
            .get();
    final current = await (_db.select(
      _db.dailyPriorities,
    )..where((p) => p.day.equals(today))).get();
    var free = maxDailyPriorities - current.length;
    var position = current.length;
    var copied = 0;
    for (final p in pending) {
      if (free <= 0) break;
      if (current.any((c) => c.title == p.title)) continue;
      await _db
          .into(_db.dailyPriorities)
          .insert(
            DailyPrioritiesCompanion.insert(
              day: today,
              title: p.title,
              position: Value(position++),
            ),
          );
      free--;
      copied++;
    }
    return copied;
  });
}

final prioritiesRepositoryProvider = Provider<PrioritiesRepository>(
  (ref) => PrioritiesRepository(ref.watch(databaseProvider)),
);

final prioritiesOfDayProvider = StreamProvider.autoDispose
    .family<List<DailyPriority>, int>(
      (ref, day) => ref.watch(prioritiesRepositoryProvider).watchDay(day),
    );

final prioritiesHistoryProvider = StreamProvider.autoDispose
    .family<List<DailyPriority>, int>(
      (ref, day) => ref.watch(prioritiesRepositoryProvider).watchHistory(day),
    );
