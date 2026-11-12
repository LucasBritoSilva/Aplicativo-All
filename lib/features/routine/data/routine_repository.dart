import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/utils/dates.dart';
import '../domain/routine_logic.dart';

/// Mudança de estado que as regras da rotina não permitem.
class RoutineStateError implements Exception {
  const RoutineStateError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Uma ocorrência com as suas sessões e a sua retomada pendente.
class OccurrenceView {
  const OccurrenceView({
    required this.occ,
    this.sessions = const [],
    this.resume,
  });

  final RoutineOccurrence occ;
  final List<RoutineSession> sessions;
  final RoutineResume? resume;

  int get id => occ.id;

  /// Tempo realizado: soma de todas as sessões da mesma ocorrência.
  int doneSeconds(DateTime now) {
    var total = 0;
    for (final s in sessions) {
      total += sessionSeconds(
        accumulatedSeconds: s.accumulatedSeconds,
        runningSince: s.runningSince,
        now: now,
      );
    }
    return total;
  }

  int get plannedSecs => plannedSeconds(occ.plannedStart, occ.plannedEnd);

  /// Aguardando retomada com horário marcado pelo usuário.
  bool get hasContinuation =>
      occ.status == OccurrenceStatus.awaitingResume &&
      resume?.scheduledDay != null;

  /// Aguardando retomada sem horário: está na Lista de Retomadas.
  bool get inResumeList =>
      occ.status == OccurrenceStatus.awaitingResume &&
      resume != null &&
      resume!.scheduledDay == null;

  DisplayState state(DateTime now, int toleranceMinutes) => displayState(
    status: occ.status,
    kind: occ.kind,
    rescheduled: occ.rescheduled,
    scheduledDay: occ.scheduledDay,
    scheduledStart: occ.scheduledStart,
    toleranceMinutes: toleranceMinutes,
    now: now,
  );
}

/// Como uma ocorrência aparece na lista de um dia.
enum DayEntryKind {
  /// Acontece neste dia.
  normal,

  /// Era deste dia, mas foi reagendada para outro.
  movedAway,

  /// Continuação marcada para este dia.
  continuation,
}

class DayEntry {
  const DayEntry(this.view, this.kind, this.start, this.end);

  final OccurrenceView view;
  final DayEntryKind kind;
  final int start;
  final int end;
}

/// Monta a programação de um dia, em ordem cronológica.
///
/// A mesma ocorrência pode aparecer no dia original (como "reagendada
/// para...") e no dia novo: é uma linha só no banco, mostrada nos dois
/// lugares para o histórico continuar claro.
List<DayEntry> buildDayEntries(List<OccurrenceView> views, int day) {
  final out = <DayEntry>[];
  for (final v in views) {
    if (v.occ.scheduledDay == day) {
      out.add(
        DayEntry(v, DayEntryKind.normal, v.occ.scheduledStart, v.occ.scheduledEnd),
      );
    } else if (v.occ.originalDay == day) {
      out.add(
        DayEntry(v, DayEntryKind.movedAway, v.occ.plannedStart, v.occ.plannedEnd),
      );
    }
    final r = v.resume;
    if (v.hasContinuation && r!.scheduledDay == day) {
      out.add(
        DayEntry(
          v,
          DayEntryKind.continuation,
          r.scheduledStart ?? 0,
          r.scheduledEnd ?? 0,
        ),
      );
    }
  }
  out.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.view.id.compareTo(b.view.id);
  });
  return out;
}

class RoutineRepository {
  RoutineRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    _db.routineOccurrences,
    _db.routineSessions,
    _db.routineResumes,
  };

  // -------------------------------------------------------------------
  // Atividades recorrentes (o planejamento)
  // -------------------------------------------------------------------

  Stream<List<RoutineActivity>> watchActivities() =>
      (_db.select(_db.routineActivities)
            ..where((a) => a.archivedDay.isNull())
            ..orderBy([
              (a) => OrderingTerm.asc(a.startMinute),
              (a) => OrderingTerm.asc(a.id),
            ]))
          .watch();

  Future<List<RoutineActivity>> activeActivities() => (_db.select(
    _db.routineActivities,
  )..where((a) => a.archivedDay.isNull())).get();

  /// Cria ou altera uma atividade recorrente.
  ///
  /// Ao alterar, só as ocorrências de hoje em diante que ainda estão
  /// intocadas (pendentes e não reagendadas) são refeitas com o novo
  /// planejamento. O que já foi iniciado, encerrado ou reagendado fica
  /// como está, e o passado nunca muda.
  Future<int> saveActivity({
    int? id,
    required String name,
    String? description,
    required ActivityKind kind,
    required int startMinute,
    required int endMinute,
    required int weekdays,
    int? singleDay,
    required bool timerEnabled,
    required DateTime now,
  }) async {
    final error = validateActivity(
      name: name,
      startMinute: startMinute,
      endMinute: endMinute,
      weekdays: weekdays,
      singleDay: singleDay,
    );
    if (error != null) throw RoutineStateError(error);

    final today = epochDay(now);
    final mask = singleDay == null ? weekdays : 0;
    final savedId = await _db.transaction(() async {
      if (id == null) {
        // Se o horário de hoje já passou inteiro, a atividade começa
        // amanhã: ninguém cria uma atividade para já nascer atrasada.
        final nowMinute = now.hour * 60 + now.minute;
        return _db
            .into(_db.routineActivities)
            .insert(
              RoutineActivitiesCompanion.insert(
                name: name.trim(),
                description: Value(description),
                kind: kind,
                startMinute: startMinute,
                endMinute: endMinute,
                weekdays: Value(mask),
                singleDay: Value(singleDay),
                timerEnabled: Value(timerEnabled),
                startDay: endMinute <= nowMinute ? today + 1 : today,
              ),
            );
      }
      await (_db.update(
        _db.routineActivities,
      )..where((a) => a.id.equals(id))).write(
        RoutineActivitiesCompanion(
          name: Value(name.trim()),
          description: Value(description),
          kind: Value(kind),
          startMinute: Value(startMinute),
          endMinute: Value(endMinute),
          weekdays: Value(mask),
          singleDay: Value(singleDay),
          timerEnabled: Value(timerEnabled),
        ),
      );
      await _deleteUntouchedFrom(id, today);
      return id;
    });
    await ensureRange(today, today + routineHorizonDays);
    if (singleDay != null) await ensureRange(singleDay, singleDay);
    return savedId;
  }

  Future<void> _deleteUntouchedFrom(int activityId, int fromDay) =>
      (_db.delete(_db.routineOccurrences)..where(
            (o) =>
                o.activityId.equals(activityId) &
                o.originalDay.isBiggerOrEqualValue(fromDay) &
                o.status.equalsValue(OccurrenceStatus.pending) &
                o.rescheduled.equals(false),
          ))
          .go();

  /// Remove a atividade do planejamento, preservando o histórico.
  ///
  /// As ocorrências futuras intocadas somem; as demais continuam no
  /// histórico. A atividade só é apagada de vez se nunca teve histórico.
  Future<void> archiveActivity(int id, int today) async {
    await _db.transaction(() async {
      await _deleteUntouchedFrom(id, today);
      final remaining =
          await (_db.select(_db.routineOccurrences)
                ..where((o) => o.activityId.equals(id))
                ..limit(1))
              .get();
      if (remaining.isEmpty) {
        await (_db.delete(
          _db.routineActivities,
        )..where((a) => a.id.equals(id))).go();
      } else {
        await (_db.update(_db.routineActivities)
              ..where((a) => a.id.equals(id)))
            .write(RoutineActivitiesCompanion(archivedDay: Value(today)));
      }
    });
  }

  // -------------------------------------------------------------------
  // Geração das ocorrências
  // -------------------------------------------------------------------

  /// Garante que cada atividade tenha a sua ocorrência em cada dia do
  /// intervalo. Pode ser chamado quantas vezes for preciso: nunca duplica.
  Future<void> ensureRange(int fromDay, int toDay) async {
    if (toDay < fromDay) return;
    final activities = await _db.select(_db.routineActivities).get();
    if (activities.isEmpty) return;
    final existing = await (_db.select(
      _db.routineOccurrences,
    )..where((o) => o.originalDay.isBetweenValues(fromDay, toDay))).get();
    final have = {for (final o in existing) (o.activityId, o.originalDay)};

    final rows = <RoutineOccurrencesCompanion>[];
    for (final a in activities) {
      for (var day = fromDay; day <= toDay; day++) {
        if (have.contains((a.id, day))) continue;
        if (!activityOccursOn(
          weekdays: a.weekdays,
          singleDay: a.singleDay,
          startDay: a.startDay,
          archivedDay: a.archivedDay,
          day: day,
        )) {
          continue;
        }
        rows.add(
          RoutineOccurrencesCompanion.insert(
            activityId: a.id,
            originalDay: day,
            name: a.name,
            kind: a.kind,
            timerEnabled: a.timerEnabled,
            plannedStart: a.startMinute,
            plannedEnd: a.endMinute,
            scheduledDay: day,
            scheduledStart: a.startMinute,
            scheduledEnd: a.endMinute,
          ),
        );
      }
    }
    if (rows.isEmpty) return;
    await _db.batch(
      (b) => b.insertAll(
        _db.routineOccurrences,
        rows,
        mode: InsertMode.insertOrIgnore,
      ),
    );
  }

  /// Gera as ocorrências dos dias que passaram com o app fechado e dos
  /// próximos [routineHorizonDays] dias.
  Future<void> ensureUpToDate(int today) async {
    final last = await _settings.readInt(
      SettingKeys.routineEnsuredThrough,
      today - 1,
    );
    var from = last + 1;
    if (from > today) from = today;
    if (from < today - 90) from = today - 90;
    await ensureRange(from, today + routineHorizonDays);
    await _settings.write(SettingKeys.routineEnsuredThrough, '$today');
  }

  // -------------------------------------------------------------------
  // Consultas
  // -------------------------------------------------------------------

  Future<List<OccurrenceView>> _views(List<RoutineOccurrence> occs) async {
    if (occs.isEmpty) return const [];
    final ids = [for (final o in occs) o.id];
    final sessions =
        await (_db.select(_db.routineSessions)
              ..where((s) => s.occurrenceId.isIn(ids))
              ..orderBy([
                (s) => OrderingTerm.asc(s.startedAt),
                (s) => OrderingTerm.asc(s.id),
              ]))
            .get();
    final resumes = await (_db.select(
      _db.routineResumes,
    )..where((r) => r.occurrenceId.isIn(ids))).get();
    final sessionsByOcc = <int, List<RoutineSession>>{};
    for (final s in sessions) {
      (sessionsByOcc[s.occurrenceId] ??= []).add(s);
    }
    final resumeByOcc = {for (final r in resumes) r.occurrenceId: r};
    return [
      for (final o in occs)
        OccurrenceView(
          occ: o,
          sessions: sessionsByOcc[o.id] ?? const [],
          resume: resumeByOcc[o.id],
        ),
    ];
  }

  Future<List<int>> _continuationIds(int fromDay, int toDay) async {
    final rows =
        await (_db.select(_db.routineResumes)..where(
              (r) =>
                  r.scheduledDay.isBetweenValues(fromDay, toDay) &
                  r.resolvedAt.isNull(),
            ))
            .get();
    return [for (final r in rows) r.occurrenceId];
  }

  /// Tudo que aparece em um dia: o que acontece nele, o que saiu dele por
  /// reagendamento e as continuações marcadas para ele.
  Future<List<OccurrenceView>> loadDay(int day) async {
    final extra = await _continuationIds(day, day);
    final occs =
        await (_db.select(_db.routineOccurrences)..where(
              (o) =>
                  o.scheduledDay.equals(day) |
                  o.originalDay.equals(day) |
                  o.id.isIn(extra),
            ))
            .get();
    return _views(occs);
  }

  Stream<List<OccurrenceView>> watchDay(int day) async* {
    await ensureRange(day, day);
    yield* _db.watchTables(_tables, () => loadDay(day));
  }

  Future<List<OccurrenceView>> loadRange(int fromDay, int toDay) async {
    final extra = await _continuationIds(fromDay, toDay);
    final occs =
        await (_db.select(_db.routineOccurrences)
              ..where(
                (o) =>
                    o.scheduledDay.isBetweenValues(fromDay, toDay) |
                    o.id.isIn(extra),
              )
              ..orderBy([
                (o) => OrderingTerm.asc(o.scheduledDay),
                (o) => OrderingTerm.asc(o.scheduledStart),
                (o) => OrderingTerm.asc(o.id),
              ]))
            .get();
    return _views(occs);
  }

  Stream<List<OccurrenceView>> watchRange(int fromDay, int toDay) async* {
    await ensureRange(fromDay, toDay);
    yield* _db.watchTables(_tables, () => loadRange(fromDay, toDay));
  }

  Future<OccurrenceView?> loadOccurrence(int id) async {
    final occ = await (_db.select(
      _db.routineOccurrences,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    if (occ == null) return null;
    return (await _views([occ])).single;
  }

  Stream<OccurrenceView?> watchOccurrence(int id) =>
      _db.watchTables(_tables, () => loadOccurrence(id));

  /// Lista de Retomadas: interrompidas sem horário para continuar, das
  /// mais antigas para as mais novas pela data de entrada na lista.
  Future<List<OccurrenceView>> loadResumeList() async {
    final rows =
        await (_db.select(_db.routineResumes)..where(
              (r) =>
                  r.resolvedAt.isNull() &
                  r.scheduledDay.isNull() &
                  r.listEnteredAt.isNotNull(),
            ))
            .get();
    final ids = [for (final r in rows) r.occurrenceId];
    final occs =
        await (_db.select(_db.routineOccurrences)..where(
              (o) =>
                  o.id.isIn(ids) &
                  o.status.equalsValue(OccurrenceStatus.awaitingResume),
            ))
            .get();
    final views = await _views(occs);
    views.sort(
      (a, b) => compareResumeEntries(
        (id: a.resume!.id, enteredAt: a.resume!.listEnteredAt!),
        (id: b.resume!.id, enteredAt: b.resume!.listEnteredAt!),
      ),
    );
    return views;
  }

  Stream<List<OccurrenceView>> watchResumeList() =>
      _db.watchTables(_tables, loadResumeList);

  /// Ocorrências que podem precisar de notificação (ver RoutineSync).
  Future<List<NotifiableOccurrence>> loadNotifiable(int today) async {
    final occs =
        await (_db.select(_db.routineOccurrences)..where(
              (o) =>
                  (o.status.equalsValue(OccurrenceStatus.pending) &
                      o.scheduledDay.isBiggerOrEqualValue(today)) |
                  o.status.equalsValue(OccurrenceStatus.awaitingResume),
            ))
            .get();
    final views = await _views(occs);
    return [
      for (final v in views)
        NotifiableOccurrence(
          id: v.id,
          name: v.occ.name,
          kind: v.occ.kind,
          status: v.occ.status,
          scheduledDay: v.occ.scheduledDay,
          scheduledStart: v.occ.scheduledStart,
          continuationDay: v.resume?.scheduledDay,
          continuationStart: v.resume?.scheduledStart,
        ),
    ];
  }

  /// Blocos de tempo ocupados em um dia, para avisar conflitos.
  Future<List<TimeBlock>> blocksOn(int day) async {
    await ensureRange(day, day);
    final views = await loadDay(day);
    final out = <TimeBlock>[];
    for (final v in views) {
      final r = v.resume;
      if (v.hasContinuation && r!.scheduledDay == day) {
        out.add(
          TimeBlock(
            id: v.id,
            name: v.occ.name,
            kind: v.occ.kind,
            day: day,
            start: r.scheduledStart ?? 0,
            end: r.scheduledEnd ?? 0,
          ),
        );
      } else if (v.occ.scheduledDay == day &&
          (v.occ.status == OccurrenceStatus.pending ||
              v.occ.status == OccurrenceStatus.inProgress ||
              v.occ.status == OccurrenceStatus.paused)) {
        out.add(
          TimeBlock(
            id: v.id,
            name: v.occ.name,
            kind: v.occ.kind,
            day: day,
            start: v.occ.scheduledStart,
            end: v.occ.scheduledEnd,
          ),
        );
      }
    }
    return out;
  }

  // -------------------------------------------------------------------
  // Ações (cada uma é uma transação: ou acontece inteira, ou nada muda)
  // -------------------------------------------------------------------

  Future<RoutineOccurrence> _get(int id) async {
    final occ = await (_db.select(
      _db.routineOccurrences,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    if (occ == null) {
      throw const RoutineStateError('Esta atividade não existe mais.');
    }
    return occ;
  }

  void _require(RoutineOccurrence occ, OccurrenceAction action) {
    if (!allowedActions(occ.status, kind: occ.kind).contains(action)) {
      throw const RoutineStateError(
        'Esta ação não está disponível no estado atual da atividade.',
      );
    }
  }

  Future<void> _write(int id, RoutineOccurrencesCompanion data) => (_db.update(
    _db.routineOccurrences,
  )..where((o) => o.id.equals(id))).write(data);

  /// Para a contagem das sessões abertas. Com [close], encerra a sessão.
  Future<void> _stopClock(int occId, DateTime now, {required bool close}) async {
    final open =
        await (_db.select(_db.routineSessions)..where(
              (s) => s.occurrenceId.equals(occId) & s.endedAt.isNull(),
            ))
            .get();
    for (final s in open) {
      await (_db.update(
        _db.routineSessions,
      )..where((x) => x.id.equals(s.id))).write(
        RoutineSessionsCompanion(
          accumulatedSeconds: Value(
            sessionSeconds(
              accumulatedSeconds: s.accumulatedSeconds,
              runningSince: s.runningSince,
              now: now,
            ),
          ),
          runningSince: const Value(null),
          endedAt: close ? Value(now) : const Value.absent(),
        ),
      );
    }
  }

  /// Inicia a atividade (também serve para "Tentar novamente" depois do
  /// atraso e para "Continuar agora" na retomada). Abre uma nova sessão.
  Future<void> start(int id, DateTime now) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, OccurrenceAction.start);
    await _db
        .into(_db.routineSessions)
        .insert(
          RoutineSessionsCompanion.insert(
            occurrenceId: id,
            startedAt: now,
            runningSince: Value(now),
          ),
        );
    await _write(
      id,
      const RoutineOccurrencesCompanion(
        status: Value(OccurrenceStatus.inProgress),
      ),
    );
    // A continuação deixa de ter horário marcado, mas a data de entrada
    // na Lista de Retomadas é preservada.
    await (_db.update(
      _db.routineResumes,
    )..where((r) => r.occurrenceId.equals(id))).write(
      const RoutineResumesCompanion(
        scheduledDay: Value(null),
        scheduledStart: Value(null),
        scheduledEnd: Value(null),
      ),
    );
  });

  Future<void> pause(int id, DateTime now) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, OccurrenceAction.pause);
    await _stopClock(id, now, close: false);
    await _write(
      id,
      const RoutineOccurrencesCompanion(status: Value(OccurrenceStatus.paused)),
    );
  });

  /// Continua depois de uma pausa, do tempo já acumulado.
  Future<void> resume(int id, DateTime now) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, OccurrenceAction.resume);
    final open =
        await (_db.select(_db.routineSessions)
              ..where((s) => s.occurrenceId.equals(id) & s.endedAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.id)])
              ..limit(1))
            .get();
    if (open.isEmpty) {
      await _db
          .into(_db.routineSessions)
          .insert(
            RoutineSessionsCompanion.insert(
              occurrenceId: id,
              startedAt: now,
              runningSince: Value(now),
            ),
          );
    } else {
      await (_db.update(_db.routineSessions)
            ..where((s) => s.id.equals(open.first.id)))
          .write(RoutineSessionsCompanion(runningSince: Value(now)));
    }
    await _write(
      id,
      const RoutineOccurrencesCompanion(
        status: Value(OccurrenceStatus.inProgress),
      ),
    );
  });

  Future<void> _close(
    int id,
    OccurrenceAction action,
    OccurrenceStatus status,
    DateTime now,
  ) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, action);
    await _stopClock(id, now, close: true);
    await _write(
      id,
      RoutineOccurrencesCompanion(status: Value(status), closedAt: Value(now)),
    );
    // Encerrar tira a ocorrência da Lista de Retomadas (fica no histórico).
    await (_db.update(_db.routineResumes)
          ..where((r) => r.occurrenceId.equals(id) & r.resolvedAt.isNull()))
        .write(RoutineResumesCompanion(resolvedAt: Value(now)));
  });

  /// Marca como concluída. Vale mesmo com menos tempo que o planejado.
  Future<void> conclude(int id, DateTime now) =>
      _close(id, OccurrenceAction.conclude, OccurrenceStatus.done, now);

  Future<void> closePartial(int id, DateTime now) =>
      _close(id, OccurrenceAction.closePartial, OccurrenceStatus.partial, now);

  Future<void> markNotDone(int id, DateTime now) =>
      _close(id, OccurrenceAction.markNotDone, OccurrenceStatus.notDone, now);

  /// Reagenda manualmente esta ocorrência. As outras ocorrências da mesma
  /// atividade e o planejamento recorrente não mudam.
  Future<void> reschedule(
    int id, {
    required int day,
    required int start,
    required int end,
  }) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, OccurrenceAction.reschedule);
    if (end <= start) {
      throw const RoutineStateError(
        'O horário de término precisa ser depois do início.',
      );
    }
    final same =
        day == occ.originalDay &&
        start == occ.plannedStart &&
        end == occ.plannedEnd;
    await _write(
      id,
      RoutineOccurrencesCompanion(
        scheduledDay: Value(day),
        scheduledStart: Value(start),
        scheduledEnd: Value(end),
        rescheduled: Value(!same),
      ),
    );
  });

  Future<void> _upsertResume(
    int occId, {
    required DateTime now,
    int? day,
    int? start,
    int? end,
    required bool enterList,
  }) async {
    final existing = await (_db.select(
      _db.routineResumes,
    )..where((r) => r.occurrenceId.equals(occId))).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.routineResumes)
          .insert(
            RoutineResumesCompanion.insert(
              occurrenceId: occId,
              createdAt: Value(now),
              listEnteredAt: Value(enterList ? now : null),
              scheduledDay: Value(day),
              scheduledStart: Value(start),
              scheduledEnd: Value(end),
            ),
          );
      return;
    }
    await (_db.update(
      _db.routineResumes,
    )..where((r) => r.id.equals(existing.id))).write(
      RoutineResumesCompanion(
        scheduledDay: Value(day),
        scheduledStart: Value(start),
        scheduledEnd: Value(end),
        resolvedAt: const Value(null),
        // A referência cronológica original nunca é sobrescrita.
        listEnteredAt: enterList && existing.listEnteredAt == null
            ? Value(now)
            : const Value.absent(),
      ),
    );
  }

  Future<void> _continueLater(
    int id,
    DateTime now, {
    int? day,
    int? start,
    int? end,
  }) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, OccurrenceAction.continueLater);
    if (day != null && (start == null || end == null || end <= start)) {
      throw const RoutineStateError(
        'O horário de término precisa ser depois do início.',
      );
    }
    await _stopClock(id, now, close: true);
    await _write(
      id,
      const RoutineOccurrencesCompanion(
        status: Value(OccurrenceStatus.awaitingResume),
      ),
    );
    await _upsertResume(
      id,
      now: now,
      day: day,
      start: start,
      end: end,
      enterList: day == null,
    );
  });

  /// "Continuar mais tarde" com data e horário escolhidos pelo usuário.
  Future<void> scheduleContinuation(
    int id, {
    required int day,
    required int start,
    required int end,
    required DateTime now,
  }) => _continueLater(id, now, day: day, start: start, end: end);

  /// "Continuar mais tarde" sem escolher horário: vai para a Lista de
  /// Retomadas. Chamar de novo não duplica nem muda a posição na lista.
  Future<void> addToResumeList(int id, DateTime now) => _continueLater(id, now);

  /// Desfaz um encerramento feito por engano.
  Future<void> reopen(int id) => _db.transaction(() async {
    final occ = await _get(id);
    _require(occ, OccurrenceAction.reopen);
    final sessions =
        await (_db.select(_db.routineSessions)
              ..where((s) => s.occurrenceId.equals(id))
              ..limit(1))
            .get();
    await _write(
      id,
      RoutineOccurrencesCompanion(
        status: Value(
          sessions.isEmpty ? OccurrenceStatus.pending : OccurrenceStatus.paused,
        ),
        closedAt: const Value(null),
      ),
    );
  });

  /// Aplica de uma vez os novos horários escolhidos em "Reorganizar".
  Future<void> applyReorganization(
    int day,
    Map<int, ({int start, int end})> changes,
  ) => _db.transaction(() async {
    for (final entry in changes.entries) {
      final occ = await _get(entry.key);
      final slot = entry.value;
      if (slot.end <= slot.start) {
        throw const RoutineStateError(
          'O horário de término precisa ser depois do início.',
        );
      }
      if (occ.status == OccurrenceStatus.awaitingResume) {
        await (_db.update(_db.routineResumes)..where(
              (r) => r.occurrenceId.equals(occ.id) & r.scheduledDay.equals(day),
            ))
            .write(
              RoutineResumesCompanion(
                scheduledStart: Value(slot.start),
                scheduledEnd: Value(slot.end),
              ),
            );
        continue;
      }
      _require(occ, OccurrenceAction.reschedule);
      final same =
          occ.scheduledDay == occ.originalDay &&
          slot.start == occ.plannedStart &&
          slot.end == occ.plannedEnd;
      await _write(
        occ.id,
        RoutineOccurrencesCompanion(
          scheduledStart: Value(slot.start),
          scheduledEnd: Value(slot.end),
          rescheduled: Value(!same),
        ),
      );
    }
  });

  // -------------------------------------------------------------------
  // Tolerância de atraso
  // -------------------------------------------------------------------

  Future<int> tolerance() => _settings.readInt(
    SettingKeys.routineTolerance,
    defaultToleranceMinutes,
  );

  Future<void> setTolerance(int minutes) =>
      _settings.write(SettingKeys.routineTolerance, '$minutes');
}

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final routineActivitiesProvider = StreamProvider<List<RoutineActivity>>(
  (ref) => ref.watch(routineRepositoryProvider).watchActivities(),
);

final routineDayProvider = StreamProvider.autoDispose
    .family<List<OccurrenceView>, int>(
      (ref, day) => ref.watch(routineRepositoryProvider).watchDay(day),
    );

/// Ocorrências de um intervalo de dias (início, fim), inclusive.
final routineRangeProvider = StreamProvider.autoDispose
    .family<List<OccurrenceView>, (int, int)>(
      (ref, range) => ref
          .watch(routineRepositoryProvider)
          .watchRange(range.$1, range.$2),
    );

final resumeListProvider = StreamProvider<List<OccurrenceView>>(
  (ref) => ref.watch(routineRepositoryProvider).watchResumeList(),
);

final occurrenceProvider = StreamProvider.autoDispose
    .family<OccurrenceView?, int>(
      (ref, id) => ref.watch(routineRepositoryProvider).watchOccurrence(id),
    );

/// Tolerância de atraso em minutos (configurável pelo usuário).
final routineToleranceProvider = Provider<int>((ref) {
  final stored = ref.watch(settingProvider(SettingKeys.routineTolerance)).value;
  return int.tryParse(stored ?? '') ?? defaultToleranceMinutes;
});
