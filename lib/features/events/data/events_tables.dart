import 'package:drift/drift.dart';

/// Resposta de um convidado.
enum Rsvp {
  waiting('Aguardando'),
  confirmed('Confirmado'),
  declined('Recusado');

  const Rsvp(this.label);
  final String label;
}

/// Tipo de item necessário para o evento.
enum NeededCategory {
  food('Comida'),
  drink('Bebida'),
  material('Material'),
  other('Outro');

  const NeededCategory(this.label);
  final String label;
}

/// Evento social.
class SocialEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get day => integer()();

  /// Horário em minutos desde a meia-noite; nulo se não tiver horário.
  IntColumn get startMinute => integer().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();

  /// Orçamento estimado.
  RealColumn get budget => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Convidados e a resposta de cada um.
class EventGuests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId =>
      integer().references(SocialEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get rsvp => textEnum<Rsvp>()();
}

/// Checklist de preparação do evento.
class EventChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId =>
      integer().references(SocialEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

/// Itens necessários (comidas, bebidas, materiais).
class EventNeededItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId =>
      integer().references(SocialEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get category => textEnum<NeededCategory>()();
  TextColumn get quantity => text().nullable()();
  BoolColumn get got => boolean().withDefault(const Constant(false))();
}

/// Gastos realizados com o evento.
class EventExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId =>
      integer().references(SocialEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text()();
  RealColumn get amount => real()();
}
