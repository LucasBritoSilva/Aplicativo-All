import 'package:drift/drift.dart';

/// Estágio de uma ideia de projeto.
enum ProjectStage {
  idea('Ideia'),
  planned('Planejado'),
  inProgress('Em andamento'),
  done('Concluído');

  const ProjectStage(this.label);
  final String label;
}

/// Ideias de projetos, com ferramentas planejadas e estágio.
class ProjectIdeas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get tools => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get stage => textEnum<ProjectStage>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
