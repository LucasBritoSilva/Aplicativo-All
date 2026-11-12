import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/app_limits/data/app_limits_tables.dart';
import '../../features/bible/data/bible_tables.dart';
import '../../features/challenges/data/challenges_tables.dart';
import '../../features/college/data/college_tables.dart';
import '../../features/contacts/data/contacts_tables.dart';
import '../../features/counters/data/counters_tables.dart';
import '../../features/events/data/events_tables.dart';
import '../../features/gym/data/gym_tables.dart';
import '../../features/knowledge/data/knowledge_tables.dart';
import '../../features/media/data/media_tables.dart';
import '../../features/priorities/data/priorities_tables.dart';
import '../../features/projects/data/projects_tables.dart';
import '../../features/routine/data/routine_tables.dart';
import '../../features/shopping/domain/shopping_section.dart';
import '../../features/tasks/domain/task_sorting.dart';
import '../../features/vault/data/vault_tables.dart';
import '../../features/wishes/data/wishes_tables.dart';
import 'core_tables.dart';
import 'tables.dart';

export '../../features/app_limits/data/app_limits_tables.dart';
export '../../features/bible/data/bible_tables.dart';
export '../../features/challenges/data/challenges_tables.dart';
export '../../features/college/data/college_tables.dart';
export '../../features/contacts/data/contacts_tables.dart';
export '../../features/counters/data/counters_tables.dart';
export '../../features/events/data/events_tables.dart';
export '../../features/gym/data/gym_tables.dart';
export '../../features/knowledge/data/knowledge_tables.dart';
export '../../features/media/data/media_tables.dart';
export '../../features/priorities/data/priorities_tables.dart';
export '../../features/projects/data/projects_tables.dart';
export '../../features/routine/data/routine_tables.dart';
export '../../features/vault/data/vault_tables.dart';
export '../../features/wishes/data/wishes_tables.dart';
export 'core_tables.dart';
export 'tables.dart';

part 'app_database.g.dart';

/// Banco SQLite local. Todos os dados do app ficam aqui, no celular.
///
/// A ordem das tabelas importa para o backup: tabelas "pai" vêm antes das
/// tabelas que apontam para elas (Habits antes de HabitChecks).
@DriftDatabase(
  tables: [
    AppSettings,
    ShoppingItems,
    WishFolders,
    WishItems,
    Tasks,
    TaskSubtasks,
    Reminders,
    Habits,
    HabitChecks,
    Goals,
    Notes,
    RoutineActivities,
    RoutineOccurrences,
    RoutineSessions,
    RoutineResumes,
    DailyPriorities,
    DayCounters,
    Challenges,
    ChallengeCheckins,
    KnowledgeItems,
    ProjectIdeas,
    UsefulContacts,
    VaultEntries,
    SocialEvents,
    EventGuests,
    EventChecklistItems,
    EventNeededItems,
    EventExpenses,
    Semesters,
    Subjects,
    Assessments,
    ExamTopics,
    WorkoutSheets,
    WorkoutExercises,
    ExerciseLoadEntries,
    BodyWeightEntries,
    MediaItems,
    BibleChapterReads,
    AppLimits,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'aplicativo_all'));

  /// Versão 2: primeira versão pública (All 2.0.0). A versão 1 era do app
  /// original, com outro identificador; não existe migração entre elas.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Reexecuta [load] sempre que alguma das [tables] mudar.
  ///
  /// Serve para telas que juntam várias tabelas (por exemplo, ocorrências,
  /// sessões e retomadas da rotina) sem perder nenhuma atualização.
  Stream<T> watchTables<T>(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) => customSelect(
    'SELECT 1',
    readsFrom: tables,
  ).watch().asyncMap((_) => load());
}

/// Instância única do banco, compartilhada pelo app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
