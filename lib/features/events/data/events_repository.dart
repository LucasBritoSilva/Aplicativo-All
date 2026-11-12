import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

/// Evento com tudo o que pertence a ele.
class EventDetails {
  const EventDetails({
    required this.event,
    required this.guests,
    required this.checklist,
    required this.needed,
    required this.expenses,
  });

  final SocialEvent event;
  final List<EventGuest> guests;
  final List<EventChecklistItem> checklist;
  final List<EventNeededItem> needed;
  final List<EventExpense> expenses;

  int countRsvp(Rsvp r) => guests.where((g) => g.rsvp == r).length;

  double get spent => expenses.fold(0, (sum, e) => sum + e.amount);

  /// Diferença entre o orçamento e o gasto (negativa = passou do orçamento).
  double? get balance => event.budget == null ? null : event.budget! - spent;

  int get checklistDone => checklist.where((c) => c.done).length;
}

class EventsRepository {
  EventsRepository(this._db);
  final AppDatabase _db;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    _db.socialEvents,
    _db.eventGuests,
    _db.eventChecklistItems,
    _db.eventNeededItems,
    _db.eventExpenses,
  };

  Stream<List<SocialEvent>> watchEvents() =>
      (_db.select(_db.socialEvents)..orderBy([
            (e) => OrderingTerm.asc(e.day),
            (e) => OrderingTerm.asc(e.startMinute),
          ]))
          .watch();

  Future<EventDetails?> load(int id) async {
    final event = await (_db.select(
      _db.socialEvents,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (event == null) return null;
    return EventDetails(
      event: event,
      guests:
          await (_db.select(_db.eventGuests)
                ..where((g) => g.eventId.equals(id))
                ..orderBy([
                  (g) => OrderingTerm.asc(g.name.collate(Collate.noCase)),
                ]))
              .get(),
      checklist:
          await (_db.select(_db.eventChecklistItems)
                ..where((c) => c.eventId.equals(id))
                ..orderBy([(c) => OrderingTerm.asc(c.id)]))
              .get(),
      needed:
          await (_db.select(_db.eventNeededItems)
                ..where((n) => n.eventId.equals(id))
                ..orderBy([
                  (n) => OrderingTerm.asc(n.category),
                  (n) => OrderingTerm.asc(n.id),
                ]))
              .get(),
      expenses:
          await (_db.select(_db.eventExpenses)
                ..where((x) => x.eventId.equals(id))
                ..orderBy([(x) => OrderingTerm.asc(x.id)]))
              .get(),
    );
  }

  Stream<EventDetails?> watch(int id) =>
      _db.watchTables(_tables, () => load(id));

  Future<int> saveEvent({
    int? id,
    required String name,
    required int day,
    int? startMinute,
    String? location,
    String? description,
    double? budget,
    String? notes,
  }) async {
    final data = SocialEventsCompanion(
      name: Value(name),
      day: Value(day),
      startMinute: Value(startMinute),
      location: Value(location),
      description: Value(description),
      budget: Value(budget),
      notes: Value(notes),
    );
    if (id == null) return _db.into(_db.socialEvents).insert(data);
    await (_db.update(
      _db.socialEvents,
    )..where((e) => e.id.equals(id))).write(data);
    return id;
  }

  Future<void> deleteEvent(int id) =>
      (_db.delete(_db.socialEvents)..where((e) => e.id.equals(id))).go();

  // Convidados
  Future<void> saveGuest(
    int eventId, {
    int? id,
    required String name,
    required Rsvp rsvp,
  }) async {
    if (id == null) {
      await _db
          .into(_db.eventGuests)
          .insert(
            EventGuestsCompanion.insert(
              eventId: eventId,
              name: name,
              rsvp: rsvp,
            ),
          );
    } else {
      await (_db.update(_db.eventGuests)..where((g) => g.id.equals(id))).write(
        EventGuestsCompanion(name: Value(name), rsvp: Value(rsvp)),
      );
    }
  }

  Future<void> setRsvp(int guestId, Rsvp rsvp) =>
      (_db.update(_db.eventGuests)..where((g) => g.id.equals(guestId))).write(
        EventGuestsCompanion(rsvp: Value(rsvp)),
      );

  Future<void> deleteGuest(int id) =>
      (_db.delete(_db.eventGuests)..where((g) => g.id.equals(id))).go();

  // Checklist
  Future<void> addChecklist(int eventId, String title) => _db
      .into(_db.eventChecklistItems)
      .insert(
        EventChecklistItemsCompanion.insert(eventId: eventId, title: title),
      );

  Future<void> setChecklistDone(int id, bool done) =>
      (_db.update(_db.eventChecklistItems)..where((c) => c.id.equals(id)))
          .write(EventChecklistItemsCompanion(done: Value(done)));

  Future<void> deleteChecklist(int id) =>
      (_db.delete(_db.eventChecklistItems)..where((c) => c.id.equals(id))).go();

  // Itens necessários
  Future<void> saveNeeded(
    int eventId, {
    int? id,
    required String name,
    required NeededCategory category,
    String? quantity,
  }) async {
    if (id == null) {
      await _db
          .into(_db.eventNeededItems)
          .insert(
            EventNeededItemsCompanion.insert(
              eventId: eventId,
              name: name,
              category: category,
              quantity: Value(quantity),
            ),
          );
    } else {
      await (_db.update(
        _db.eventNeededItems,
      )..where((n) => n.id.equals(id))).write(
        EventNeededItemsCompanion(
          name: Value(name),
          category: Value(category),
          quantity: Value(quantity),
        ),
      );
    }
  }

  Future<void> setNeededGot(int id, bool got) =>
      (_db.update(_db.eventNeededItems)..where((n) => n.id.equals(id))).write(
        EventNeededItemsCompanion(got: Value(got)),
      );

  Future<void> deleteNeeded(int id) =>
      (_db.delete(_db.eventNeededItems)..where((n) => n.id.equals(id))).go();

  // Gastos
  Future<void> saveExpense(
    int eventId, {
    int? id,
    required String description,
    required double amount,
  }) async {
    if (id == null) {
      await _db
          .into(_db.eventExpenses)
          .insert(
            EventExpensesCompanion.insert(
              eventId: eventId,
              description: description,
              amount: amount,
            ),
          );
    } else {
      await (_db.update(
        _db.eventExpenses,
      )..where((x) => x.id.equals(id))).write(
        EventExpensesCompanion(
          description: Value(description),
          amount: Value(amount),
        ),
      );
    }
  }

  Future<void> deleteExpense(int id) =>
      (_db.delete(_db.eventExpenses)..where((x) => x.id.equals(id))).go();
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(databaseProvider)),
);

final eventsProvider = StreamProvider<List<SocialEvent>>(
  (ref) => ref.watch(eventsRepositoryProvider).watchEvents(),
);

final eventDetailsProvider = StreamProvider.autoDispose
    .family<EventDetails?, int>(
      (ref, id) => ref.watch(eventsRepositoryProvider).watch(id),
    );
