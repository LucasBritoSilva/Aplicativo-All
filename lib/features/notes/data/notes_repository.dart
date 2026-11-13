import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/native/native_bridge.dart';

/// Apaga arquivos de imagem (no app, pelo lado nativo; nos testes, falso).
typedef DeleteFiles = Future<void> Function(List<String> paths);

class NotesRepository {
  NotesRepository(this._db, this._deleteFiles);

  final AppDatabase _db;
  final DeleteFiles _deleteFiles;

  /// Fixadas primeiro; depois as alteradas mais recentemente.
  Stream<List<Note>> watchAll() =>
      (_db.select(_db.notes)..orderBy([
            (n) => OrderingTerm.desc(n.pinned),
            (n) => OrderingTerm.desc(n.updatedAt),
          ]))
          .watch();

  /// Imagens de todas as notas, agrupadas pelo id da nota, em ordem.
  Stream<Map<int, List<NoteImage>>> watchImages() =>
      (_db.select(_db.noteImages)..orderBy([
            (i) => OrderingTerm.asc(i.position),
            (i) => OrderingTerm.asc(i.id),
          ]))
          .watch()
          .map((rows) {
            final out = <int, List<NoteImage>>{};
            for (final r in rows) {
              (out[r.noteId] ??= []).add(r);
            }
            return out;
          });

  Future<List<NoteImage>> imagesOf(int noteId) =>
      (_db.select(_db.noteImages)
            ..where((i) => i.noteId.equals(noteId))
            ..orderBy([
              (i) => OrderingTerm.asc(i.position),
              (i) => OrderingTerm.asc(i.id),
            ]))
          .get();

  Future<void> setPinned(int id, bool pinned) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(pinned: Value(pinned)),
      );

  /// Cria ou altera a nota e devolve o id.
  Future<int> save({
    int? id,
    String? title,
    required String body,
    bool fromVoice = false,
  }) async {
    final cleanTitle = (title == null || title.trim().isEmpty)
        ? null
        : title.trim();
    if (id == null) {
      return _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              title: Value(cleanTitle),
              body: body,
              fromVoice: Value(fromVoice),
            ),
          );
    }
    await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        title: Value(cleanTitle),
        body: Value(body),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  /// Deixa a nota com exatamente estas imagens, nesta ordem. As que saíram
  /// têm o arquivo apagado.
  Future<void> setImages(int noteId, List<String> paths) async {
    final removed = <String>[];
    await _db.transaction(() async {
      final current = await imagesOf(noteId);
      for (final img in current) {
        if (!paths.contains(img.path)) removed.add(img.path);
      }
      await (_db.delete(
        _db.noteImages,
      )..where((i) => i.noteId.equals(noteId))).go();
      for (final (i, path) in paths.indexed) {
        await _db
            .into(_db.noteImages)
            .insert(
              NoteImagesCompanion.insert(
                noteId: noteId,
                path: path,
                position: Value(i),
              ),
            );
      }
    });
    await _deleteFiles(removed);
  }

  /// Exclui a nota e os arquivos das imagens dela.
  Future<void> delete(int id) async {
    final images = await imagesOf(id);
    await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
    await _deleteFiles([for (final i in images) i.path]);
  }

  /// Apaga arquivos escolhidos mas não guardados (nota descartada).
  Future<void> discardFiles(List<String> paths) => _deleteFiles(paths);
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final native = ref.watch(nativeBridgeProvider);
  return NotesRepository(ref.watch(databaseProvider), native.deleteFiles);
});

final notesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(notesRepositoryProvider).watchAll(),
);

final noteImagesProvider = StreamProvider<Map<int, List<NoteImage>>>(
  (ref) => ref.watch(notesRepositoryProvider).watchImages(),
);
