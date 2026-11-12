import 'package:drift/drift.dart';

/// Pastas (setores) personalizadas da lista de desejos.
class WishFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Produtos desejados. Sem pasta = [folderId] nulo ("Sem pasta").
class WishItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get link => text().nullable()();
  RealColumn get price => real().nullable()();
  TextColumn get notes => text().nullable()();

  /// Se a pasta for excluída, o item não é apagado: fica sem pasta.
  IntColumn get folderId => integer().nullable().references(
    WishFolders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get acquired => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
