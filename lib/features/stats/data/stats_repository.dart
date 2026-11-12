import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/utils/dates.dart';
import '../../routine/data/routine_repository.dart';
import '../../routine/domain/routine_logic.dart';

/// Indicadores de um período, todos calculados a partir dos registros
/// reais. Um indicador nulo significa "sem dados" (a tela mostra vazio).
class StatsSnapshot {
  const StatsSnapshot({
    required this.days,
    required this.tasksCompleted,
    required this.tasksPending,
    required this.prioritiesSet,
    required this.prioritiesDone,
    required this.routine,
    required this.habitChecks,
    required this.habitConstancy,
    required this.challengeCheckins,
    required this.challengesCompleted,
    required this.knowledgeTotal,
    required this.knowledgeRated,
    required this.knowledgeAverage,
    required this.starsHistogram,
    required this.loadChanges,
    required this.weightFirst,
    required this.weightLast,
    required this.weightEntries,
    required this.bibleChapters,
    required this.mediaWatched,
  });

  final int days;
  final int tasksCompleted;
  final int tasksPending;
  final int prioritiesSet;
  final int prioritiesDone;
  final RoutineSummary routine;
  final int habitChecks;

  /// Fração das metas semanais cumpridas (nulo sem hábitos).
  final double? habitConstancy;
  final int challengeCheckins;
  final int challengesCompleted;
  final int knowledgeTotal;
  final int knowledgeRated;
  final double? knowledgeAverage;

  /// Quantidade de conhecimentos com 1, 2, 3, 4 e 5 estrelas.
  final List<int> starsHistogram;
  final int loadChanges;
  final double? weightFirst;
  final double? weightLast;
  final int weightEntries;
  final int bibleChapters;
  final int mediaWatched;

  double? get weightChange =>
      weightFirst == null || weightLast == null || weightEntries < 2
      ? null
      : weightLast! - weightFirst!;
}

/// Constância dos hábitos: para cada hábito e cada semana do período,
/// quanto da meta semanal foi cumprido (limitado a 100%), na média.
double? habitConstancy({
  required List<({int id, int weeklyTarget})> habits,
  required List<({int habitId, DateTime day})> checks,
  required DateTime from,
  required DateTime to,
}) {
  if (habits.isEmpty) return null;
  final weeks = <DateTime>{};
  for (var d = startOfWeek(from); !d.isAfter(to); d = addDays(d, 7)) {
    weeks.add(d);
  }
  var sum = 0.0;
  var count = 0;
  for (final h in habits) {
    if (h.weeklyTarget <= 0) continue;
    for (final w in weeks) {
      final end = addDays(w, 7);
      final done = {
        for (final c in checks)
          if (c.habitId == h.id && !c.day.isBefore(w) && c.day.isBefore(end))
            dateOnly(c.day),
      }.length;
      sum += (done / h.weeklyTarget).clamp(0.0, 1.0);
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}

class StatsRepository {
  StatsRepository(this._db, this._routine);

  final AppDatabase _db;
  final RoutineRepository _routine;

  Future<StatsSnapshot> load({required int days, required DateTime now}) async {
    final todayDate = dateOnly(now);
    final fromDate = addDays(todayDate, -(days - 1));
    final toExclusive = addDays(todayDate, 1);
    final today = epochDay(todayDate);
    final fromDay = today - days + 1;

    bool inRange(DateTime? d) =>
        d != null && !d.isBefore(fromDate) && d.isBefore(toExclusive);

    final tasks = await _db.select(_db.tasks).get();
    final priorities = await (_db.select(
      _db.dailyPriorities,
    )..where((p) => p.day.isBetweenValues(fromDay, today))).get();

    final occurrences = await _routine.loadRange(fromDay, today);
    final routine = summarizeRoutine([
      for (final v in occurrences)
        if (v.occ.scheduledDay >= fromDay && v.occ.scheduledDay <= today)
          (
            status: v.occ.status,
            kind: v.occ.kind,
            timerSeconds: v.occ.timerEnabled ? v.doneSeconds(now) : 0,
          ),
    ]);

    final habits = await _db.select(_db.habits).get();
    final checks = await _db.select(_db.habitChecks).get();
    final checksInRange = [
      for (final c in checks)
        if (inRange(c.day)) c,
    ];

    final checkins = await (_db.select(
      _db.challengeCheckins,
    )..where((c) => c.day.isBetweenValues(fromDay, today))).get();
    final challenges = await _db.select(_db.challenges).get();

    final knowledge = await _db.select(_db.knowledgeItems).get();
    final rated = [
      for (final k in knowledge)
        if (k.stars != null) k.stars!,
    ];

    final loads = await (_db.select(
      _db.exerciseLoadEntries,
    )..where((l) => l.day.isBetweenValues(fromDay, today))).get();
    final weights =
        await (_db.select(_db.bodyWeightEntries)
              ..where((w) => w.day.isBetweenValues(fromDay, today))
              ..orderBy([(w) => OrderingTerm.asc(w.day)]))
            .get();

    final bible = await _db.select(_db.bibleChapterReads).get();
    final media = await _db.select(_db.mediaItems).get();

    return StatsSnapshot(
      days: days,
      tasksCompleted: tasks
          .where((t) => t.done && inRange(t.completedAt))
          .length,
      tasksPending: tasks.where((t) => !t.done).length,
      prioritiesSet: priorities.length,
      prioritiesDone: priorities.where((p) => p.done).length,
      routine: routine,
      habitChecks: checksInRange.length,
      habitConstancy: habitConstancy(
        habits: [
          for (final h in habits) (id: h.id, weeklyTarget: h.weeklyTarget),
        ],
        checks: [
          for (final c in checksInRange) (habitId: c.habitId, day: c.day),
        ],
        from: fromDate,
        to: todayDate,
      ),
      challengeCheckins: checkins.length,
      challengesCompleted: challenges
          .where((c) => inRange(c.completedAt))
          .length,
      knowledgeTotal: knowledge.length,
      knowledgeRated: rated.length,
      knowledgeAverage: rated.isEmpty
          ? null
          : rated.fold<int>(0, (s, v) => s + v) / rated.length,
      starsHistogram: [
        for (var s = 1; s <= 5; s++) rated.where((v) => v == s).length,
      ],
      loadChanges: loads.length,
      weightFirst: weights.firstOrNull?.weight,
      weightLast: weights.lastOrNull?.weight,
      weightEntries: weights.length,
      bibleChapters: bible.where((b) => inRange(b.readAt)).length,
      mediaWatched: media
          .where((m) => m.watched && inRange(m.watchedAt))
          .length,
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(
    ref.watch(databaseProvider),
    ref.watch(routineRepositoryProvider),
  ),
);

/// Recalcula quando qualquer tabela usada nas estatísticas muda.
final statsProvider = StreamProvider.autoDispose.family<StatsSnapshot, int>((
  ref,
  days,
) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(statsRepositoryProvider);
  // Garante as ocorrências da rotina do período antes de contar.
  ref.watch(settingsRepositoryProvider);
  return db.watchTables({
    db.tasks,
    db.dailyPriorities,
    db.routineOccurrences,
    db.routineSessions,
    db.habits,
    db.habitChecks,
    db.challenges,
    db.challengeCheckins,
    db.knowledgeItems,
    db.exerciseLoadEntries,
    db.bodyWeightEntries,
    db.bibleChapterReads,
    db.mediaItems,
  }, () => repo.load(days: days, now: DateTime.now()));
});
