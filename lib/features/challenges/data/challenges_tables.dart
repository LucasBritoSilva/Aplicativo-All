import 'package:drift/drift.dart';

/// Como o desafio é medido.
enum ChallengeMode {
  /// Por duração: um registro por dia, até completar N dias.
  days('Por dias'),

  /// Por quantidade: soma dos registros até atingir o alvo.
  count('Por quantidade');

  const ChallengeMode(this.label);
  final String label;
}

/// Desafio pessoal com duração (dias) ou quantidade alvo.
class Challenges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get mode => textEnum<ChallengeMode>()();
  IntColumn get target => integer()();
  TextColumn get unit => text().nullable()();
  IntColumn get startDay => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Registro (check-in) de um desafio em um dia.
class ChallengeCheckins extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId =>
      integer().references(Challenges, #id, onDelete: KeyAction.cascade)();
  IntColumn get day => integer()();
  IntColumn get amount => integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {challengeId, day},
  ];
}
