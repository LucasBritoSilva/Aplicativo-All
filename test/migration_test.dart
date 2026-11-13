import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Banco com as tabelas da versão 2 (All 2.0.0) que mudaram na versão 3.
AppDatabase _v2Database() => AppDatabase(
  NativeDatabase.memory(
    setup: (raw) {
      raw.execute('''
        CREATE TABLE media_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          kind TEXT NOT NULL,
          title TEXT NOT NULL,
          watched INTEGER NOT NULL DEFAULT 0,
          rating REAL NULL,
          season INTEGER NULL,
          episode INTEGER NULL,
          total_episodes INTEGER NULL,
          notes TEXT NULL,
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
          watched_at INTEGER NULL
        );''');
      raw.execute('''
        CREATE TABLE app_limits (
          package_name TEXT NOT NULL,
          label TEXT NOT NULL,
          limit_minutes INTEGER NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          PRIMARY KEY (package_name)
        );''');
      raw.execute(
        "INSERT INTO media_items (kind, title, watched, rating) VALUES "
        "('movie', 'Matrix', 1, 9.5), ('series', 'Dark', 0, NULL), "
        "('anime', 'Naruto', 0, NULL)",
      );
      raw.execute(
        "INSERT INTO app_limits (package_name, label, limit_minutes) "
        "VALUES ('com.instagram.android', 'Instagram', 60)",
      );
      raw.execute('PRAGMA user_version = 2');
    },
  ),
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('instalação nova cria só Filmes e Séries', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cats = await db.select(db.mediaCategories).get();
    expect(cats.map((c) => c.name), ['Filmes', 'Séries']);
    expect(cats.map((c) => c.hasEpisodes), [false, true]);
    await db.close();
  });

  test('2.0.0 -> 3: títulos vão para as categorias sem perder nada', () async {
    final db = _v2Database();
    final cats = {
      for (final c in await db.select(db.mediaCategories).get()) c.id: c,
    };
    expect(cats.values.map((c) => c.name).toSet(), {
      'Filmes',
      'Séries',
      'Animes',
    });

    final items = await db.select(db.mediaItems).get();
    String categoryOf(String title) =>
        cats[items.firstWhere((i) => i.title == title).categoryId]!.name;
    expect(items, hasLength(3));
    expect(categoryOf('Matrix'), 'Filmes');
    expect(categoryOf('Dark'), 'Séries');
    expect(categoryOf('Naruto'), 'Animes');
    final matrix = items.firstWhere((i) => i.title == 'Matrix');
    expect(matrix.rating, 9.5);
    expect(matrix.watched, isTrue);
    await db.close();
  });

  test(
    '2.0.0 -> 3: limites antigos ficam no modo contador flutuante',
    () async {
      final db = _v2Database();
      final limit = await db.select(db.appLimits).getSingle();
      expect(limit.limitMinutes, 60);
      expect(limit.mode, LimitMode.overlay);
      await db.close();
    },
  );
}
