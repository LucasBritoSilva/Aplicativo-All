import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Nomes das preferências guardadas no banco.
abstract final class SettingKeys {
  /// Lista (JSON) dos módulos abertos mais recentemente.
  static const recentModules = 'recent_modules';

  /// Tolerância de atraso da rotina, em minutos.
  static const routineTolerance = 'routine_tolerance_minutes';

  /// Último dia para o qual as ocorrências da rotina foram geradas.
  static const routineEnsuredThrough = 'routine_ensured_through';

  /// Estado do cronômetro de pausas (JSON).
  static const breakTimer = 'break_timer';

  /// Meta de peso corporal, em kg.
  static const weightGoal = 'gym_weight_goal';

  /// Cânon escolhido na leitura da Bíblia.
  static const bibleCanon = 'bible_canon';

  /// Último sorteio de números e opções do decisor (JSON).
  static const decider = 'decider';

  /// Se o monitor de uso de apps está ligado.
  static const appLimitsMonitor = 'app_limits_monitor';
}

/// Lê e grava preferências simples (texto) no banco local.
class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String?> read(String name) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.name.equals(name))).getSingleOrNull();
    return row?.content;
  }

  Stream<String?> watch(String name) => (_db.select(
    _db.appSettings,
  )..where((s) => s.name.equals(name))).watchSingleOrNull().map(
    (row) => row?.content,
  );

  Future<void> write(String name, String content) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(name: name, content: content),
      );

  Future<void> remove(String name) =>
      (_db.delete(_db.appSettings)..where((s) => s.name.equals(name))).go();

  Future<int> readInt(String name, int fallback) async =>
      int.tryParse(await read(name) ?? '') ?? fallback;
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Valor atual de uma preferência; atualiza sozinho quando ela muda.
final settingProvider = StreamProvider.family<String?, String>(
  (ref, name) => ref.watch(settingsRepositoryProvider).watch(name),
);
