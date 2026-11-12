import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../domain/bible_books.dart';

class BibleRepository {
  BibleRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  Stream<Map<String, Set<int>>> watchRead() =>
      _db.select(_db.bibleChapterReads).watch().map((rows) {
        final out = <String, Set<int>>{};
        for (final r in rows) {
          (out[r.bookId] ??= {}).add(r.chapter);
        }
        return out;
      });

  Future<void> setRead(String bookId, int chapter, bool read) async {
    if (read) {
      await _db
          .into(_db.bibleChapterReads)
          .insert(
            BibleChapterReadsCompanion.insert(bookId: bookId, chapter: chapter),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(_db.bibleChapterReads)
            ..where((r) => r.bookId.equals(bookId) & r.chapter.equals(chapter)))
          .go();
    }
  }

  /// Marca ou desmarca o livro inteiro.
  Future<void> setBook(BibleBook book, Canon canon, bool read) =>
      _db.transaction(() async {
        if (!read) {
          await (_db.delete(
            _db.bibleChapterReads,
          )..where((r) => r.bookId.equals(book.id))).go();
          return;
        }
        await _db.batch(
          (b) => b.insertAll(_db.bibleChapterReads, [
            for (var c = 1; c <= book.chaptersIn(canon); c++)
              BibleChapterReadsCompanion.insert(bookId: book.id, chapter: c),
          ], mode: InsertMode.insertOrIgnore),
        );
      });

  Future<void> setCanon(Canon canon) =>
      _settings.write(SettingKeys.bibleCanon, canon.name);
}

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final bibleReadProvider = StreamProvider<Map<String, Set<int>>>(
  (ref) => ref.watch(bibleRepositoryProvider).watchRead(),
);

/// Cânon escolhido (padrão: protestante, até o usuário trocar).
final bibleCanonProvider = Provider<Canon>((ref) {
  final raw = ref.watch(settingProvider(SettingKeys.bibleCanon)).value;
  return Canon.values.asNameMap()[raw] ?? Canon.protestant;
});

final bibleProgressProvider = Provider<AsyncValue<BibleProgress>>((ref) {
  final canon = ref.watch(bibleCanonProvider);
  return ref
      .watch(bibleReadProvider)
      .whenData((read) => BibleProgress(canon, read));
});

/// Leitura da Bíblia: checklist de livros e capítulos (sem o texto).
class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  void _openBook(BuildContext context, BibleBook book) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => _BookScreen(book: book)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bibleProgressProvider);
    final canon = ref.watch(bibleCanonProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitura da Bíblia'),
        actions: [
          PopupMenuButton<Canon>(
            tooltip: 'Cânon',
            icon: const Icon(Icons.library_books_outlined),
            initialValue: canon,
            onSelected: (c) => ref.read(bibleRepositoryProvider).setCanon(c),
            itemBuilder: (_) => [
              for (final c in Canon.values)
                PopupMenuItem(value: c, child: Text(c.label)),
            ],
          ),
        ],
      ),
      body: progress.view((p) {
        final next = p.continueAt();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${percentOf(p.fraction())}% da Bíblia',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(value: p.fraction(), height: 8),
                    const SizedBox(height: 8),
                    Text(
                      '${p.readCount()} de ${totalChapters(canon)} capítulos · ${canon.label}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    for (final t in Testament.values)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${t.label}: ${percentOf(p.fraction(testament: t))}% '
                          '(${p.readCount(testament: t)}/${totalChapters(canon, testament: t)})',
                          style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (next == null)
                      const Text(
                        'Leitura completa! 🎉',
                        style: TextStyle(color: AppColors.success),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _openBook(context, next.book),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          'Continuar: ${next.book.name} ${next.chapter}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final t in Testament.values) ...[
              SectionLabel(
                t.label,
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              ),
              Card(
                child: Column(
                  children: [
                    for (final b in booksOf(
                      canon,
                    ).where((b) => b.testament == t))
                      ListTile(
                        onTap: () => _openBook(context, b),
                        title: Text(b.name),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ProgressBar(
                            value: p.bookFraction(b),
                            height: 4,
                          ),
                        ),
                        trailing: Text(
                          '${p.readIn(b)}/${b.chaptersIn(canon)}',
                          style: TextStyle(
                            color: p.readIn(b) == b.chaptersIn(canon)
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _BookScreen extends ConsumerWidget {
  const _BookScreen({required this.book});

  final BibleBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bibleProgressProvider);
    final canon = ref.watch(bibleCanonProvider);
    final repo = ref.read(bibleRepositoryProvider);
    final total = book.chaptersIn(canon);
    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: progress.view((p) {
        final allRead = p.readIn(book) == total;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(
              '${p.readIn(book)} de $total capítulos lidos · ${percentOf(p.bookFraction(book))}%',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            ProgressBar(value: p.bookFraction(book), height: 8),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var c = 1; c <= total; c++)
                  SizedBox(
                    width: 52,
                    height: 44,
                    child: FilterChip(
                      showCheckmark: false,
                      label: SizedBox(
                        width: double.infinity,
                        child: Text('$c', textAlign: TextAlign.center),
                      ),
                      selected: p.isRead(book, c),
                      onSelected: (v) => repo.setRead(book.id, c, v),
                      tooltip: 'Capítulo $c',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                if (allRead) {
                  final ok = await confirm(
                    context,
                    title: 'Desmarcar o livro',
                    message: 'Desmarcar todos os capítulos de ${book.name}?',
                    confirmLabel: 'Desmarcar',
                  );
                  if (!ok) return;
                }
                await repo.setBook(book, canon, !allRead);
              },
              icon: Icon(allRead ? Icons.remove_done : Icons.done_all),
              label: Text(
                allRead ? 'Desmarcar todos' : 'Marcar o livro inteiro',
              ),
            ),
          ],
        );
      }),
    );
  }
}
