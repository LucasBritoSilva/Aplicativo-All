import 'package:drift/drift.dart';

/// Capítulos da Bíblia marcados como lidos.
///
/// A lista de livros e capítulos fica no código (`bible_books.dart`); aqui
/// só entram as marcações. Trocar de cânon não apaga nenhuma marcação.
class BibleChapterReads extends Table {
  TextColumn get bookId => text()();
  IntColumn get chapter => integer()();
  DateTimeColumn get readAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId, chapter};
}
