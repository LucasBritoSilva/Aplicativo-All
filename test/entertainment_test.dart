import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:aplicativo_all/features/media/data/media_repository.dart';
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late MediaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
  });
  tearDown(() => db.close());

  Future<MediaCategory> cat(String name) async =>
      (await db.select(db.mediaCategories).get()).firstWhere(
        (c) => c.name == name,
      );

  test('criar, renomear e reordenar categorias', () async {
    final id = await repo.saveCategory(
      name: 'Documentários',
      hasEpisodes: false,
    );
    await repo.saveCategory(id: id, name: 'Docs', hasEpisodes: true);
    final docs = await cat('Docs');
    expect(docs.hasEpisodes, isTrue);
    await repo.moveCategory(id, -1);
    final ordered = await (db.select(
      db.mediaCategories,
    )..orderBy([(c) => OrderingTerm.asc(c.position)])).get();
    expect(ordered.map((c) => c.name), ['Filmes', 'Docs', 'Séries']);
  });

  test('título sem episódios ignora temporada e episódio', () async {
    final filmes = await cat('Filmes');
    await repo.saveItem(
      category: filmes,
      title: 'Matrix',
      season: 2,
      episode: 3,
    );
    final item = await db.select(db.mediaItems).getSingle();
    expect(item.categoryId, filmes.id);
    expect(item.season, isNull);
    expect(item.episode, isNull);
  });

  test('excluir categoria movendo os títulos não perde nada', () async {
    final filmes = await cat('Filmes');
    final series = await cat('Séries');
    await repo.saveItem(category: filmes, title: 'Matrix', rating: 9);
    await repo.deleteCategory(filmes.id, moveTo: series.id);
    final item = await db.select(db.mediaItems).getSingle();
    expect(item.categoryId, series.id);
    expect(item.rating, 9);
    expect((await db.select(db.mediaCategories).get()).map((c) => c.name), [
      'Séries',
    ]);
  });

  test('categoria com títulos não é excluída sem escolha explícita', () async {
    final filmes = await cat('Filmes');
    await repo.saveItem(category: filmes, title: 'Matrix');
    await expectLater(repo.deleteCategory(filmes.id), throwsStateError);
    expect(await db.select(db.mediaItems).get(), hasLength(1));
    await repo.deleteCategory(filmes.id, deleteItems: true);
    expect(await db.select(db.mediaItems).get(), isEmpty);
  });

  test('categorias excluídas não voltam sozinhas', () async {
    for (final c in await db.select(db.mediaCategories).get()) {
      await repo.deleteCategory(c.id);
    }
    expect(await db.select(db.mediaCategories).get(), isEmpty);
  });
}
