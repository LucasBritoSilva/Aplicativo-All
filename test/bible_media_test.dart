import 'dart:math';

import 'package:aplicativo_all/features/bible/domain/bible_books.dart';
import 'package:aplicativo_all/features/media/data/media_tables.dart';
import 'package:aplicativo_all/features/media/domain/media_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bíblia', () {
    test('cânon protestante: 66 livros e 1.189 capítulos', () {
      expect(booksOf(Canon.protestant), hasLength(66));
      expect(totalChapters(Canon.protestant), 1189);
      expect(totalChapters(Canon.protestant, testament: Testament.old), 929);
      expect(totalChapters(Canon.protestant, testament: Testament.newT), 260);
      expect(
        booksOf(Canon.protestant).where((b) => b.testament == Testament.old),
        hasLength(39),
      );
    });

    test('cânon católico: 73 livros com os deuterocanônicos', () {
      final books = booksOf(Canon.catholic);
      expect(books, hasLength(73));
      expect(books.where((b) => b.testament == Testament.old), hasLength(46));
      expect(books.where((b) => b.deuterocanonical), hasLength(7));
      // 929 + 137 dos deuterocanônicos + 2 capítulos de Daniel.
      expect(totalChapters(Canon.catholic, testament: Testament.old), 1068);
      expect(totalChapters(Canon.catholic, testament: Testament.newT), 260);
    });

    test('ids dos livros são únicos', () {
      final ids = allBibleBooks.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('progresso por livro e geral', () {
      final gn = allBibleBooks.first;
      final p = BibleProgress(Canon.protestant, {
        'gn': {for (var c = 1; c <= 25; c++) c},
        'jd': {1},
      });
      expect(p.readIn(gn), 25);
      expect(p.bookFraction(gn), 0.5);
      expect(p.readCount(), 26);
      expect(percentOf(p.fraction()), 2);
    });

    test('marcações fora do cânon não contam, mas não somem', () {
      final read = {
        'tb': {1, 2},
        'dn': {13},
      };
      final protestant = BibleProgress(Canon.protestant, read);
      expect(protestant.readCount(), 0);
      final catholic = BibleProgress(Canon.catholic, read);
      expect(catholic.readCount(), 3);
    });

    test('continuar a leitura do ponto onde parou', () {
      expect(BibleProgress(Canon.protestant, {}).continueAt()!.book.id, 'gn');
      final next = BibleProgress(Canon.protestant, {
        'gn': {for (var c = 1; c <= 50; c++) c},
        'ex': {1, 2},
      }).continueAt()!;
      expect(next.book.id, 'ex');
      expect(next.chapter, 3);
      final afterBook = BibleProgress(Canon.protestant, {
        'rt': {1, 2, 3, 4},
      }).continueAt()!;
      expect(afterBook.book.id, '1sm');
      expect(afterBook.chapter, 1);
    });
  });

  group('Filmes, séries e animes', () {
    MediaEntry e(int id, MediaKind k, String t, bool w, double? r) =>
        (id: id, kind: k, title: t, watched: w, rating: r);

    final items = [
      e(1, MediaKind.movie, 'B', true, 8),
      e(2, MediaKind.movie, 'A', true, 9.5),
      e(3, MediaKind.movie, 'C', true, null),
      e(4, MediaKind.movie, 'D', false, 10),
      e(5, MediaKind.series, 'E', false, null),
      e(6, MediaKind.anime, 'F', false, null),
      e(7, MediaKind.movie, 'Aa', true, 8),
    ];

    test('ranking só tem assistidos com nota, da maior para a menor', () {
      final rank = rankWatched(items, (x) => x);
      expect(rank.map((x) => x.id), [2, 7, 1]);
    });

    test('sorteio só escolhe não assistidos do tipo pedido', () {
      final r = Random(1);
      for (var i = 0; i < 20; i++) {
        final pick = drawUnwatched(
          items,
          (x) => x,
          kind: MediaKind.movie,
          random: r,
        );
        expect(pick!.id, 4);
        final any = drawUnwatched(items, (x) => x, random: r)!;
        expect(any.watched, isFalse);
      }
      expect(
        drawUnwatched(
          [e(1, MediaKind.anime, 'X', true, 5)],
          (x) => x,
          kind: MediaKind.anime,
        ),
        isNull,
      );
    });

    test('sortear de novo evita repetir quando há outra opção', () {
      final r = Random(3);
      for (var i = 0; i < 20; i++) {
        expect(
          drawUnwatched(items, (x) => x, avoidId: 5, random: r)!.id,
          isNot(5),
        );
      }
    });

    test('progresso de episódios', () {
      expect(episodeProgress(5, null), isNull);
      expect(episodeProgress(5, 10), 0.5);
      expect(episodeProgress(12, 10), 1);
    });
  });
}
