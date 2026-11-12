import 'package:drift/drift.dart';

/// Contatos úteis (cadastro local, sem acesso à agenda do sistema).
class UsefulContacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
