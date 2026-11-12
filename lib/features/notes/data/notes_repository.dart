import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

class NotesRepository {
  NotesRepository(this._db);
  final AppDatabase _db;

  Stream<List<Note>> watchAll() => (_db.select(
    _db.notes,
  )..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])).watch();

  Future<void> save({
    int? id,
    String? title,
    required String body,
    bool fromVoice = false,
  }) async {
    final cleanTitle = (title == null || title.trim().isEmpty)
        ? null
        : title.trim();
    if (id == null) {
      await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              title: Value(cleanTitle),
              body: body,
              fromVoice: Value(fromVoice),
            ),
          );
    } else {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          title: Value(cleanTitle),
          body: Value(body),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
}

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(databaseProvider)),
);

final notesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(notesRepositoryProvider).watchAll(),
);
