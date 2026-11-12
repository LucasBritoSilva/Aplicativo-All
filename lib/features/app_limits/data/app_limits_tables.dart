import 'package:drift/drift.dart';

/// Limite diário de uso de um aplicativo instalado.
class AppLimits extends Table {
  TextColumn get packageName => text()();
  TextColumn get label => text()();
  IntColumn get limitMinutes => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {packageName};
}
