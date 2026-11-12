import 'package:drift/drift.dart';

/// Preferências e pequenos estados do app (chave e valor em texto).
///
/// Guarda, por exemplo, os módulos recentes da tela inicial, a tolerância
/// de atraso da rotina e o estado do cronômetro de pausas.
class AppSettings extends Table {
  TextColumn get name => text()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {name};
}
