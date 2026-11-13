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
    MediaCategories,
    MediaItems,
    BibleChapterReads,
    AppLimits,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'aplicativo_all'));

  /// Versão 2: All 2.0.0. Versão 3: BrutAll (categorias do Entretenimento
  /// e modo de acompanhamento dos limites de apps). A versão 1 era do app
  /// original, com outro identificador; não existe migração dela.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createDefaultMediaCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        await m.createTable(mediaCategories);
        await m.addColumn(mediaItems, mediaItems.categoryId);
        await m.addColumn(appLimits, appLimits.mode);
        await _migrateMediaToCategories();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Categorias iniciais do Entretenimento (o usuário pode renomear ou
  /// excluir; não são recriadas depois).
  Future<({int movies, int series})> _createDefaultMediaCategories() async {
    final movies = await into(mediaCategories).insert(
      MediaCategoriesCompanion.insert(name: 'Filmes', position: const Value(0)),
    );
    final series = await into(mediaCategories).insert(
      MediaCategoriesCompanion.insert(
        name: 'Séries',
        hasEpisodes: const Value(true),
        position: const Value(1),
      ),
    );
    return (movies: movies, series: series);
  }

  /// Versão 2 -> 3: cada título antigo vai para a categoria do seu tipo.
  /// Só cria "Animes" se já houver animes cadastrados.
  Future<void> _migrateMediaToCategories() async {
    final ids = await _createDefaultMediaCategories();
    await customUpdate(
      "UPDATE media_items SET category_id = ? WHERE kind = 'movie'",
      variables: [Variable<int>(ids.movies)],
      updates: {mediaItems},
    );
    await customUpdate(
      "UPDATE media_items SET category_id = ? WHERE kind = 'series'",
      variables: [Variable<int>(ids.series)],
      updates: {mediaItems},
    );
    final animes = await customSelect(
      "SELECT COUNT(*) AS n FROM media_items WHERE kind = 'anime'",
    ).getSingle();
    if (animes.read<int>('n') > 0) {
      final anime = await into(mediaCategories).insert(
        MediaCategoriesCompanion.insert(
          name: 'Animes',
          hasEpisodes: const Value(true),
          position: const Value(2),
        ),
      );
      await customUpdate(
        "UPDATE media_items SET category_id = ? WHERE kind = 'anime'",
        variables: [Variable<int>(anime)],
        updates: {mediaItems},
      );
    }
  }

  /// Reexecuta [load] sempre que alguma das [tables] mudar.
  ///
  /// Serve para telas que juntam várias tabelas (por exemplo, ocorrências,
  /// sessões e retomadas da rotina) sem perder nenhuma atualização.
  ///
  /// O drift reaproveita streams iguais pela consulta SQL e pelos valores,
  /// sem olhar as tabelas observadas. Por isso a consulta leva o nome das
  /// tabelas como valor: cada conjunto de tabelas tem o seu próprio stream.
  Stream<T> watchTables<T>(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) {
    final key = (tables.map((t) => t.entityName).toList()..sort()).join(',');
    return customSelect(
      'SELECT ? AS observed_tables',
      variables: [Variable<String>(key)],
      readsFrom: tables,
    ).watch().asyncMap((_) => load());
  }
}

/// Instância única do banco, compartilhada pelo app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
