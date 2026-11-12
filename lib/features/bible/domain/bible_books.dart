/// Livros e número de capítulos da Bíblia (só os metadados; nenhum texto
/// bíblico é incluído no app).
///
/// Divisão de capítulos: a usual nas Bíblias em português (Almeida). No
/// cânon católico entram os 7 livros deuterocanônicos e Daniel tem 14
/// capítulos (13 e 14: Susana, Bel e o Dragão). Ver DECISOES.md.
library;

enum Testament {
  old('Antigo Testamento'),
  newT('Novo Testamento');

  const Testament(this.label);
  final String label;
}

enum Canon {
  protestant('Protestante (66 livros)'),
  catholic('Católico (73 livros)');

  const Canon(this.label);
  final String label;
}

class BibleBook {
  const BibleBook(
    this.id,
    this.name,
    this.testament,
    this.protestantChapters, {
    this.catholicChapters,
    this.deuterocanonical = false,
  });

  /// Identificador estável gravado nas marcações. Não mude.
  final String id;
  final String name;
  final Testament testament;

  /// Capítulos no cânon protestante (0 se o livro não faz parte dele).
  final int protestantChapters;

  /// Capítulos no cânon católico, quando diferente.
  final int? catholicChapters;
  final bool deuterocanonical;

  int chaptersIn(Canon canon) => canon == Canon.catholic
      ? (catholicChapters ?? protestantChapters)
      : protestantChapters;
}

const _ot = Testament.old;
const _nt = Testament.newT;

/// Todos os livros, na ordem católica (que contém a protestante).
const allBibleBooks = <BibleBook>[
  BibleBook('gn', 'Gênesis', _ot, 50),
  BibleBook('ex', 'Êxodo', _ot, 40),
  BibleBook('lv', 'Levítico', _ot, 27),
  BibleBook('nm', 'Números', _ot, 36),
  BibleBook('dt', 'Deuteronômio', _ot, 34),
  BibleBook('js', 'Josué', _ot, 24),
  BibleBook('jz', 'Juízes', _ot, 21),
  BibleBook('rt', 'Rute', _ot, 4),
  BibleBook('1sm', '1 Samuel', _ot, 31),
  BibleBook('2sm', '2 Samuel', _ot, 24),
  BibleBook('1rs', '1 Reis', _ot, 22),
  BibleBook('2rs', '2 Reis', _ot, 25),
  BibleBook('1cr', '1 Crônicas', _ot, 29),
  BibleBook('2cr', '2 Crônicas', _ot, 36),
  BibleBook('ed', 'Esdras', _ot, 10),
  BibleBook('ne', 'Neemias', _ot, 13),
  BibleBook(
    'tb',
    'Tobias',
    _ot,
    0,
    catholicChapters: 14,
    deuterocanonical: true,
  ),
  BibleBook(
    'jt',
    'Judite',
    _ot,
    0,
    catholicChapters: 16,
    deuterocanonical: true,
  ),
  BibleBook('et', 'Ester', _ot, 10),
  BibleBook(
    '1mc',
    '1 Macabeus',
    _ot,
    0,
    catholicChapters: 16,
    deuterocanonical: true,
  ),
  BibleBook(
    '2mc',
    '2 Macabeus',
    _ot,
    0,
    catholicChapters: 15,
    deuterocanonical: true,
  ),
  BibleBook('jo', 'Jó', _ot, 42),
  BibleBook('sl', 'Salmos', _ot, 150),
  BibleBook('pv', 'Provérbios', _ot, 31),
  BibleBook('ec', 'Eclesiastes', _ot, 12),
  BibleBook('ct', 'Cânticos', _ot, 8),
  BibleBook(
    'sb',
    'Sabedoria',
    _ot,
    0,
    catholicChapters: 19,
    deuterocanonical: true,
  ),
  BibleBook(
    'eclo',
    'Eclesiástico',
    _ot,
    0,
    catholicChapters: 51,
    deuterocanonical: true,
  ),
  BibleBook('is', 'Isaías', _ot, 66),
  BibleBook('jr', 'Jeremias', _ot, 52),
  BibleBook('lm', 'Lamentações', _ot, 5),
  BibleBook('br', 'Baruc', _ot, 0, catholicChapters: 6, deuterocanonical: true),
  BibleBook('ez', 'Ezequiel', _ot, 48),
  BibleBook('dn', 'Daniel', _ot, 12, catholicChapters: 14),
  BibleBook('os', 'Oseias', _ot, 14),
  BibleBook('jl', 'Joel', _ot, 3),
  BibleBook('am', 'Amós', _ot, 9),
  BibleBook('ob', 'Obadias', _ot, 1),
  BibleBook('jn', 'Jonas', _ot, 4),
  BibleBook('mq', 'Miqueias', _ot, 7),
  BibleBook('na', 'Naum', _ot, 3),
  BibleBook('hc', 'Habacuque', _ot, 3),
  BibleBook('sf', 'Sofonias', _ot, 3),
  BibleBook('ag', 'Ageu', _ot, 2),
  BibleBook('zc', 'Zacarias', _ot, 14),
  BibleBook('ml', 'Malaquias', _ot, 4),
  BibleBook('mt', 'Mateus', _nt, 28),
  BibleBook('mc', 'Marcos', _nt, 16),
  BibleBook('lc', 'Lucas', _nt, 24),
  BibleBook('joa', 'João', _nt, 21),
  BibleBook('at', 'Atos', _nt, 28),
  BibleBook('rm', 'Romanos', _nt, 16),
  BibleBook('1co', '1 Coríntios', _nt, 16),
  BibleBook('2co', '2 Coríntios', _nt, 13),
  BibleBook('gl', 'Gálatas', _nt, 6),
  BibleBook('ef', 'Efésios', _nt, 6),
  BibleBook('fp', 'Filipenses', _nt, 4),
  BibleBook('cl', 'Colossenses', _nt, 4),
  BibleBook('1ts', '1 Tessalonicenses', _nt, 5),
  BibleBook('2ts', '2 Tessalonicenses', _nt, 3),
  BibleBook('1tm', '1 Timóteo', _nt, 6),
  BibleBook('2tm', '2 Timóteo', _nt, 4),
  BibleBook('tt', 'Tito', _nt, 3),
  BibleBook('fm', 'Filemom', _nt, 1),
  BibleBook('hb', 'Hebreus', _nt, 13),
  BibleBook('tg', 'Tiago', _nt, 5),
  BibleBook('1pe', '1 Pedro', _nt, 5),
  BibleBook('2pe', '2 Pedro', _nt, 3),
  BibleBook('1joa', '1 João', _nt, 5),
  BibleBook('2joa', '2 João', _nt, 1),
  BibleBook('3joa', '3 João', _nt, 1),
  BibleBook('jd', 'Judas', _nt, 1),
  BibleBook('ap', 'Apocalipse', _nt, 22),
];

/// Livros do cânon escolhido, na ordem.
List<BibleBook> booksOf(Canon canon) => [
  for (final b in allBibleBooks)
    if (b.chaptersIn(canon) > 0) b,
];

int totalChapters(Canon canon, {Testament? testament}) =>
    booksOf(canon)
        .where((b) => testament == null || b.testament == testament)
        .fold(0, (sum, b) => sum + b.chaptersIn(canon));

/// Progresso de leitura a partir das marcações (livro -> capítulos lidos).
/// Marcações fora do cânon escolhido são ignoradas (e não apagadas).
class BibleProgress {
  BibleProgress(this.canon, Map<String, Set<int>> read) : _read = read;

  final Canon canon;
  final Map<String, Set<int>> _read;

  int readIn(BibleBook b) {
    final chapters = _read[b.id];
    if (chapters == null) return 0;
    final max = b.chaptersIn(canon);
    return chapters.where((c) => c >= 1 && c <= max).length;
  }

  bool isRead(BibleBook b, int chapter) =>
      _read[b.id]?.contains(chapter) ?? false;

  double bookFraction(BibleBook b) {
    final total = b.chaptersIn(canon);
    return total == 0 ? 0 : readIn(b) / total;
  }

  int readCount({Testament? testament}) =>
      booksOf(canon)
          .where((b) => testament == null || b.testament == testament)
          .fold(0, (sum, b) => sum + readIn(b));

  double fraction({Testament? testament}) {
    final total = totalChapters(canon, testament: testament);
    return total == 0 ? 0 : readCount(testament: testament) / total;
  }

  /// Onde continuar: o primeiro capítulo não lido depois do último lido,
  /// na ordem da Bíblia. Nulo se tudo foi lido.
  ({BibleBook book, int chapter})? continueAt() {
    final books = booksOf(canon);
    var lastBook = -1, lastChapter = 0;
    for (var i = 0; i < books.length; i++) {
      final b = books[i];
      for (var c = 1; c <= b.chaptersIn(canon); c++) {
        if (isRead(b, c)) {
          lastBook = i;
          lastChapter = c;
        }
      }
    }
    ({BibleBook book, int chapter})? firstUnread(
      int fromBook,
      int fromChapter,
    ) {
      for (var i = fromBook; i < books.length; i++) {
        final b = books[i];
        for (
          var c = i == fromBook ? fromChapter : 1;
          c <= b.chaptersIn(canon);
          c++
        ) {
          if (!isRead(b, c)) return (book: b, chapter: c);
        }
      }
      return null;
    }

    if (lastBook < 0) return (book: books.first, chapter: 1);
    return firstUnread(lastBook, lastChapter + 1) ?? firstUnread(0, 1);
  }
}

/// Percentual sem arredondar para cima (só 100% quando terminou).
int percentOf(double fraction) => (fraction * 100).floor();
