import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shopping/domain/shopping_section.dart';
import '../../features/tasks/domain/task_sorting.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// Banco SQLite local. Todos os dados do app ficam aqui, no celular.
///
/// A ordem das tabelas importa para o backup: tabelas "pai" vêm antes
/// das tabelas que apontam para elas (Habits antes de HabitChecks).
@DriftDatabase(
  tables: [
    ShoppingItems,
    RoutineItems,
    AgendaEvents,
    Tasks,
    Reminders,
    Habits,
    HabitChecks,
    Goals,
    Notes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'app_pessoal'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Instância única do banco, compartilhada pelo app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
