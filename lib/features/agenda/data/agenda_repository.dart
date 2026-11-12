import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

class AgendaRepository {
  AgendaRepository(this._db);
  final AppDatabase _db;

  /// Eventos que tocam o intervalo [start, end).
  Stream<List<AgendaEvent>> watchRange(DateTime start, DateTime end) {
    final t = _db.agendaEvents;
    return (_db.select(t)
          ..where(
            (e) =>
                e.startsAt.isSmallerThanValue(end) &
                coalesce<DateTime>([
                  e.endsAt,
                  e.startsAt,
                ]).isBiggerOrEqualValue(start),
          )
          ..orderBy([
            (e) => OrderingTerm.desc(e.allDay),
            (e) => OrderingTerm.asc(e.startsAt),
          ]))
        .watch();
  }

  Future<void> save({
    int? id,
    required String title,
    String? notes,
    required DateTime startsAt,
    DateTime? endsAt,
    required bool allDay,
  }) async {
    final data = AgendaEventsCompanion(
      title: Value(title),
      notes: Value(notes),
      startsAt: Value(startsAt),
      endsAt: Value(endsAt),
      allDay: Value(allDay),
    );
    if (id == null) {
      await _db.into(_db.agendaEvents).insert(data);
    } else {
      await (_db.update(
        _db.agendaEvents,
      )..where((e) => e.id.equals(id))).write(data);
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.agendaEvents)..where((e) => e.id.equals(id))).go();
}

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(ref.watch(databaseProvider)),
);

/// Eventos de um intervalo (início inclusivo, fim exclusivo).
final agendaRangeProvider =
    StreamProvider.family<List<AgendaEvent>, (DateTime, DateTime)>(
      (ref, range) =>
          ref.watch(agendaRepositoryProvider).watchRange(range.$1, range.$2),
    );
