import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/utils/dates.dart';
import '../domain/routine_logic.dart';
import 'routine_repository.dart';
import 'routine_tables.dart';

/// Mantém as ocorrências e as notificações da rotina em dia.
///
/// Roda ao abrir o app, ao voltar para ele, na virada do dia e depois de
/// cada ação que muda o planejamento. O celular reiniciado é tratado pelo
/// plugin de notificações, que reagenda sozinho o que estava marcado.
class RoutineSync {
  RoutineSync(this._repo, this._notifications);

  final RoutineRepository _repo;
  final NotificationService _notifications;

  /// Gera as ocorrências que faltam e confere as notificações.
  Future<void> run() async {
    try {
      await _repo.ensureUpToDate(epochDay(DateTime.now()));
    } catch (e) {
      debugPrint('Falha ao preparar a rotina: $e');
    }
    await syncNotifications();
  }

  /// Deixa agendada exatamente uma notificação por atividade que ainda vai
  /// começar, e cancela as que não valem mais (atividade iniciada antes da
  /// hora, encerrada, reagendada ou removida do planejamento).
  Future<void> syncNotifications() async {
    try {
      final now = DateTime.now();
      final desired = planRoutineNotifications(
        occurrences: await _repo.loadNotifiable(epochDay(now)),
        now: now,
      );
      final pending = await _notifications.pendingPayloads();
      final wanted = {for (final d in desired) d.id};
      for (final id in pending.keys) {
        if (isRoutineNotificationId(id) && !wanted.contains(id)) {
          await _notifications.cancel(id);
        }
      }
      for (final d in desired) {
        // Mesmo id e mesmo horário: já está agendada.
        if (pending[d.id] == d.payload) continue;
        await _notifications.schedule(
          id: d.id,
          title: d.title,
          when: d.when,
          payload: d.payload,
          channel: AppChannel.routine,
        );
      }
    } catch (e) {
      debugPrint('Falha ao sincronizar notificações da rotina: $e');
    }
  }
}

/// Ações da rotina usadas pelas telas: executa no banco e, em seguida,
/// atualiza as notificações.
class RoutineActions {
  RoutineActions(this._repo, this._sync);

  final RoutineRepository _repo;
  final RoutineSync _sync;

  Future<void> _run(Future<void> Function() action) async {
    await action();
    await _sync.syncNotifications();
  }

  Future<void> saveActivity({
    int? id,
    required String name,
    String? description,
    required ActivityKind kind,
    required int startMinute,
    required int endMinute,
    required int weekdays,
    int? singleDay,
    required bool timerEnabled,
  }) => _run(
    () => _repo.saveActivity(
      id: id,
      name: name,
      description: description,
      kind: kind,
      startMinute: startMinute,
      endMinute: endMinute,
      weekdays: weekdays,
      singleDay: singleDay,
      timerEnabled: timerEnabled,
      now: DateTime.now(),
    ),
  );

  Future<void> archiveActivity(int id) =>
      _run(() => _repo.archiveActivity(id, epochDay(DateTime.now())));

  Future<void> start(int id) => _run(() => _repo.start(id, DateTime.now()));

  Future<void> pause(int id) => _repo.pause(id, DateTime.now());

  Future<void> resume(int id) => _repo.resume(id, DateTime.now());

  Future<void> conclude(int id) =>
      _run(() => _repo.conclude(id, DateTime.now()));

  Future<void> closePartial(int id) =>
      _run(() => _repo.closePartial(id, DateTime.now()));

  Future<void> markNotDone(int id) =>
      _run(() => _repo.markNotDone(id, DateTime.now()));

  Future<void> reschedule(
    int id, {
    required int day,
    required int start,
    required int end,
  }) => _run(() => _repo.reschedule(id, day: day, start: start, end: end));

  Future<void> scheduleContinuation(
    int id, {
    required int day,
    required int start,
    required int end,
  }) => _run(
    () => _repo.scheduleContinuation(
      id,
      day: day,
      start: start,
      end: end,
      now: DateTime.now(),
    ),
  );

  Future<void> addToResumeList(int id) =>
      _run(() => _repo.addToResumeList(id, DateTime.now()));

  Future<void> reopen(int id) => _run(() => _repo.reopen(id));

  Future<void> applyReorganization(
    int day,
    Map<int, ({int start, int end})> changes,
  ) => _run(() => _repo.applyReorganization(day, changes));
}

final routineSyncProvider = Provider<RoutineSync>(
  (ref) => RoutineSync(
    ref.watch(routineRepositoryProvider),
    ref.watch(notificationServiceProvider),
  ),
);

final routineActionsProvider = Provider<RoutineActions>(
  (ref) => RoutineActions(
    ref.watch(routineRepositoryProvider),
    ref.watch(routineSyncProvider),
  ),
);
