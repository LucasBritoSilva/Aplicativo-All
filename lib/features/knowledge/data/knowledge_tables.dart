import 'package:drift/drift.dart';

/// Conhecimentos e assuntos, com domínio avaliado de 1 a 5 estrelas.
class KnowledgeItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();

  /// 1 a 5 estrelas; nulo enquanto não foi avaliado.
  IntColumn get stars => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
