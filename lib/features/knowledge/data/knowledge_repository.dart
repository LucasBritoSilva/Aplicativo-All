import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

/// Ordem da lista de conhecimentos.
enum KnowledgeSort {
  name('Nome'),
  starsDesc('Mais domínio'),
  starsAsc('Menos domínio'),
  recent('Recentes');

  const KnowledgeSort(this.label);
  final String label;
}

/// Ordena sem alterar a lista original. Itens sem avaliação ficam por
/// último nas ordens por estrelas.
List<KnowledgeItem> sortKnowledge(List<KnowledgeItem> items, KnowledgeSort sort) {
  int byName(KnowledgeItem a, KnowledgeItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  final list = [...items];
  switch (sort) {
    case KnowledgeSort.name:
      list.sort(byName);
    case KnowledgeSort.recent:
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case KnowledgeSort.starsDesc || KnowledgeSort.starsAsc:
      final desc = sort == KnowledgeSort.starsDesc;
      list.sort((a, b) {
        if (a.stars == null && b.stars == null) return byName(a, b);
        if (a.stars == null) return 1;
        if (b.stars == null) return -1;
        final c = desc ? b.stars!.compareTo(a.stars!) : a.stars!.compareTo(b.stars!);
        return c != 0 ? c : byName(a, b);
      });
  }
  return list;
}

class KnowledgeRepository {
  KnowledgeRepository(this._db);
  final AppDatabase _db;

  Stream<List<KnowledgeItem>> watchAll() => _db.select(_db.knowledgeItems).watch();

  Future<void> save({
    int? id,
    required String title,
    String? description,
    String? category,
    int? stars,
  }) async {
    if (stars != null && (stars < 1 || stars > 5)) {
      throw ArgumentError.value(stars, 'stars', 'precisa ser de 1 a 5');
    }
    final data = KnowledgeItemsCompanion(
      title: Value(title),
      description: Value(description),
      category: Value(category),
      stars: Value(stars),
      updatedAt: Value(DateTime.now()),
    );
    if (id == null) {
      await _db.into(_db.knowledgeItems).insert(data);
    } else {
      await (_db.update(_db.knowledgeItems)..where((k) => k.id.equals(id))).write(data);
    }
  }

  Future<void> setStars(int id, int? stars) =>
      (_db.update(_db.knowledgeItems)..where((k) => k.id.equals(id))).write(
        KnowledgeItemsCompanion(
          stars: Value(stars),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.knowledgeItems)..where((k) => k.id.equals(id))).go();
}

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
  (ref) => KnowledgeRepository(ref.watch(databaseProvider)),
);

final knowledgeProvider = StreamProvider<List<KnowledgeItem>>(
  (ref) => ref.watch(knowledgeRepositoryProvider).watchAll(),
);
