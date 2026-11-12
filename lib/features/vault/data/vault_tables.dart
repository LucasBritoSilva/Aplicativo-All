import 'package:drift/drift.dart';

/// Registros do cofre. Todo o conteúdo (título, categoria e texto) fica
/// dentro de [payload], cifrado com AES-256-GCM pelo lado nativo. O banco
/// nunca guarda o texto aberto.
@DataClassName('VaultEntry')
class VaultEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Base64 de: vetor de inicialização (12 bytes) + texto cifrado + tag.
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
