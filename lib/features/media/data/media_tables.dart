import 'package:drift/drift.dart';

/// Tipo antigo dos títulos (versão 2.0.0, com três abas fixas).
///
/// Continua gravado em cada título só por compatibilidade: a organização
/// agora é feita pelas categorias ([MediaCategories]). A migração usa este
/// valor para colocar os títulos antigos na categoria certa.
enum MediaKind {
  movie('Filme', 'Filmes'),
  series('Série', 'Séries'),
  anime('Anime', 'Animes');

  const MediaKind(this.label, this.plural);
  final String label;
  final String plural;

  bool get hasEpisodes => this != MediaKind.movie;
}

/// Categorias do Entretenimento, criadas e organizadas pelo usuário.
///
/// [hasEpisodes] liga o acompanhamento de temporada e episódio para os
/// títulos da categoria (séries, animes, novelas...).
@DataClassName('MediaCategory')
class MediaCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get hasEpisodes => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Títulos para assistir e assistidos.
class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<MediaKind>()();

  /// Categoria do título. Excluir uma categoria pede antes para mover ou
  /// apagar os títulos dela; o nulo só existe por segurança.
  IntColumn get categoryId => integer().nullable().references(
    MediaCategories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text()();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();

  /// Nota de 0 a 10; nulo enquanto não foi avaliado.
  RealColumn get rating => real().nullable()();
  IntColumn get season => integer().nullable()();
  IntColumn get episode => integer().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get watchedAt => dateTime().nullable()();
}
