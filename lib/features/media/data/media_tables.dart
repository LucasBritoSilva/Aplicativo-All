import 'package:drift/drift.dart';

/// As três listas independentes do módulo.
enum MediaKind {
  movie('Filme', 'Filmes'),
  series('Série', 'Séries'),
  anime('Anime', 'Animes');

  const MediaKind(this.label, this.plural);
  final String label;
  final String plural;

  /// Séries e animes acompanham temporada e episódio.
  bool get hasEpisodes => this != MediaKind.movie;
}

/// Filmes, séries e animes para assistir e assistidos.
class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<MediaKind>()();
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
