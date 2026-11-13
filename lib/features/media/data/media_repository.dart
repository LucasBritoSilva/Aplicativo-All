import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/media_logic.dart';

MediaEntry mediaEntry(MediaItem m) => (
  id: m.id,
  categoryId: m.categoryId,
  title: m.title,
  watched: m.watched,
  rating: m.rating,
);

/// Categorias e títulos do Entretenimento.
class MediaData {
  const MediaData(this.categories, this.items);

  final List<MediaCategory> categories;
  final List<MediaItem> items;

  List<MediaItem> itemsOf(int categoryId) =>
      items.where((i) => i.categoryId == categoryId).toList();

  MediaCategory? category(int? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class MediaRepository {
  MediaRepository(this._db);
  final AppDatabase _db;

  Future<MediaData> _load() async {
    final categories =
        await (_db.select(_db.mediaCategories)..orderBy([
              (c) => OrderingTerm.asc(c.position),
              (c) => OrderingTerm.asc(c.id),
            ]))
            .get();
    final items =
        await (_db.select(_db.mediaItems)..orderBy([
              (m) => OrderingTerm.asc(m.title.collate(Collate.noCase)),
            ]))
            .get();
    return MediaData(categories, items);
  }

  Stream<MediaData> watch() =>
      _db.watchTables({_db.mediaCategories, _db.mediaItems}, _load);

  // ---- Categorias ----

  Future<int> saveCategory({
    int? id,
    required String name,
    required bool hasEpisodes,
  }) async {
    if (id != null) {
      await (_db.update(
        _db.mediaCategories,
      )..where((c) => c.id.equals(id))).write(
        MediaCategoriesCompanion(
          name: Value(name.trim()),
          hasEpisodes: Value(hasEpisodes),
        ),
      );
      return id;
    }
    final all = await _db.select(_db.mediaCategories).get();
    final next = all.fold<int>(-1, (m, c) => c.position > m ? c.position : m);
    return _db
        .into(_db.mediaCategories)
        .insert(
          MediaCategoriesCompanion.insert(
            name: name.trim(),
            hasEpisodes: Value(hasEpisodes),
            position: Value(next + 1),
          ),
        );
  }

  /// Move a categoria uma posição para a esquerda ([delta] -1) ou direita.
  Future<void> moveCategory(int id, int delta) => _db.transaction(() async {
    final all =
        await (_db.select(_db.mediaCategories)..orderBy([
              (c) => OrderingTerm.asc(c.position),
              (c) => OrderingTerm.asc(c.id),
            ]))
            .get();
    final ids = [for (final c in all) c.id];
    final from = ids.indexOf(id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= ids.length) return;
    ids.insert(to, ids.removeAt(from));
    for (final (i, cid) in ids.indexed) {
      await (_db.update(_db.mediaCategories)..where((c) => c.id.equals(cid)))
          .write(MediaCategoriesCompanion(position: Value(i)));
    }
  });

  /// Exclui a categoria. Os títulos dela vão para [moveTo]; se [moveTo] for
  /// nulo, só exclui quando [deleteItems] confirmar a exclusão dos títulos.
  Future<void> deleteCategory(
    int id, {
    int? moveTo,
    bool deleteItems = false,
  }) => _db.transaction(() async {
    if (moveTo == id) {
      throw ArgumentError('O destino não pode ser a própria categoria.');
    }
    final items = await (_db.select(
      _db.mediaItems,
    )..where((m) => m.categoryId.equals(id))).get();
    if (items.isNotEmpty) {
      if (moveTo != null) {
        final target = await (_db.select(
          _db.mediaCategories,
        )..where((c) => c.id.equals(moveTo))).getSingle();
        await (_db.update(
          _db.mediaItems,
        )..where((m) => m.categoryId.equals(id))).write(
          MediaItemsCompanion(
            categoryId: Value(moveTo),
            kind: Value(
              target.hasEpisodes ? MediaKind.series : MediaKind.movie,
            ),
          ),
        );
      } else if (deleteItems) {
        await (_db.delete(
          _db.mediaItems,
        )..where((m) => m.categoryId.equals(id))).go();
      } else {
        throw StateError('A categoria tem títulos: escolha o que fazer.');
      }
    }
    await (_db.delete(_db.mediaCategories)..where((c) => c.id.equals(id))).go();
  });

  // ---- Títulos ----

  Future<void> saveItem({
    int? id,
    required MediaCategory category,
    required String title,
    double? rating,
    int? season,
    int? episode,
    int? totalEpisodes,
    String? notes,
  }) async {
    final data = MediaItemsCompanion(
      categoryId: Value(category.id),
      kind: Value(category.hasEpisodes ? MediaKind.series : MediaKind.movie),
      title: Value(title),
      rating: Value(rating),
      season: Value(category.hasEpisodes ? season : null),
      episode: Value(category.hasEpisodes ? episode : null),
      totalEpisodes: Value(category.hasEpisodes ? totalEpisodes : null),
      notes: Value(notes),
    );
    if (id == null) {
      await _db.into(_db.mediaItems).insert(data);
    } else {
      await (_db.update(
        _db.mediaItems,
      )..where((m) => m.id.equals(id))).write(data);
    }
  }

  Future<void> setWatched(int id, bool watched) =>
      (_db.update(_db.mediaItems)..where((m) => m.id.equals(id))).write(
        MediaItemsCompanion(
          watched: Value(watched),
          watchedAt: Value(watched ? DateTime.now() : null),
        ),
      );

  /// Avança um episódio (sem passar do total, se informado).
  Future<void> nextEpisode(MediaItem m) {
    final next = (m.episode ?? 0) + 1;
    final capped = m.totalEpisodes != null && next > m.totalEpisodes!
        ? m.totalEpisodes!
        : next;
    return (_db.update(_db.mediaItems)..where((x) => x.id.equals(m.id))).write(
      MediaItemsCompanion(episode: Value(capped)),
    );
  }

  Future<void> deleteItem(int id) =>
      (_db.delete(_db.mediaItems)..where((m) => m.id.equals(id))).go();
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(databaseProvider)),
);

final mediaProvider = StreamProvider<MediaData>(
  (ref) => ref.watch(mediaRepositoryProvider).watch(),
);
