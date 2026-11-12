import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';

class RemindersRepository {
  RemindersRepository(this._db);
  final AppDatabase _db;

  Stream<List<Reminder>> watchAll() => (_db.select(
    _db.reminders,
  )..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)])).watch();

  Future<List<Reminder>> upcoming(DateTime now) => (_db.select(
    _db.reminders,
  )..where((r) => r.scheduledAt.isBiggerThanValue(now))).get();

  /// Salva e devolve o id do lembrete.
  Future<int> save({
    int? id,
    required String title,
    String? notes,
    required DateTime scheduledAt,
  }) async {
    final data = RemindersCompanion(
      title: Value(title),
      notes: Value(notes),
      scheduledAt: Value(scheduledAt),
    );
    if (id == null) return _db.into(_db.reminders).insert(data);
    await (_db.update(
      _db.reminders,
    )..where((r) => r.id.equals(id))).write(data);
    return id;
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();

  Future<int> clearPast(DateTime now) => (_db.delete(
    _db.reminders,
  )..where((r) => r.scheduledAt.isSmallerOrEqualValue(now))).go();
}

/// Junta o banco e as notificações: todo lembrete salvo é agendado, e todo
/// lembrete excluído tem a notificação cancelada. O id da notificação é o
/// próprio id do lembrete.
class ReminderScheduler {
  ReminderScheduler(this._repo, this._notifications);
  final RemindersRepository _repo;
  final NotificationService _notifications;

  Future<ScheduleOutcome> save({
    int? id,
    required String title,
    String? notes,
    required DateTime scheduledAt,
  }) async {
    final savedId = await _repo.save(
      id: id,
      title: title,
      notes: notes,
      scheduledAt: scheduledAt,
    );
    return _notifications.schedule(
      id: savedId,
      title: title,
      body: notes,
      when: scheduledAt,
    );
  }

  Future<void> delete(int id) async {
    await _notifications.cancel(id);
    await _repo.delete(id);
  }

  Future<void> clearPast() => _repo.clearPast(DateTime.now());

  /// Garante que as notificações agendadas batem com o banco.
  ///
  /// Roda ao abrir o app e depois de restaurar um backup. A reinicialização
  /// do celular é tratada pelo próprio plugin (ScheduledNotificationBootReceiver).
  Future<void> resync() async {
    final now = DateTime.now();
    final future = await _repo.upcoming(now);
    final keep = {for (final r in future) r.id};
    for (final pendingId in await _notifications.pendingIds()) {
      // Só mexe nos ids dos lembretes: a rotina e as pausas usam faixas
      // próprias, bem acima dos ids do banco.
      if (isReminderNotificationId(pendingId) && !keep.contains(pendingId)) {
        await _notifications.cancel(pendingId);
      }
    }
    for (final r in future) {
      await _notifications.schedule(
        id: r.id,
        title: r.title,
        body: r.notes,
        when: r.scheduledAt,
      );
    }
  }
}

/// Ids de notificação usados pelos lembretes (o próprio id do banco).
bool isReminderNotificationId(int id) => id > 0 && id < 900000000;

final remindersRepositoryProvider = Provider<RemindersRepository>(
  (ref) => RemindersRepository(ref.watch(databaseProvider)),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(
    ref.watch(remindersRepositoryProvider),
    ref.watch(notificationServiceProvider),
  ),
);

final remindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(remindersRepositoryProvider).watchAll(),
);
