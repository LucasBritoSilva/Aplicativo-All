import 'package:drift/drift.dart';

/// Como o app acompanha o limite de um aplicativo.
enum LimitMode {
  /// Contador flutuante com o tempo restante sobre o app monitorado.
  overlay('Contador flutuante'),

  /// Uma notificação quando o limite do dia é atingido.
  notify('Notificação ao atingir o limite');

  const LimitMode(this.label);
  final String label;
}

/// Limite diário de uso de um aplicativo instalado.
class AppLimits extends Table {
  TextColumn get packageName => text()();
  TextColumn get label => text()();
  IntColumn get limitMinutes => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get mode =>
      textEnum<LimitMode>().withDefault(const Constant('overlay'))();

  @override
  Set<Column> get primaryKey => {packageName};
}
