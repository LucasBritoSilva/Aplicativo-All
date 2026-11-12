import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/challenge_logic.dart';

class ChallengeView {
  const ChallengeView(this.challenge, this.checkins);

  final Challenge challenge;
  final List<ChallengeCheckin> checkins;

  ChallengeProgress progress(int today) => challengeProgress(
    mode: challenge.mode,
    target: challenge.target,
    checkins: [for (final c in checkins) (c.day, c.amount)],
    today: today,
  );

  int amountOn(int day) {
    for (final c in checkins) {
      if (c.day == day) return c.amount;
    }
    return 0;
  }
}

class ChallengesRepository {
  ChallengesRepository(this._db);
  final AppDatabase _db;

  Future<List<ChallengeView>> _load() async {
    final challenges = await (_db.select(
      _db.challenges,
    )..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();
    final checkins = await (_db.select(
      _db.challengeCheckins,
    )..orderBy([(c) => OrderingTerm.asc(c.day)])).get();
    final byChallenge = <int, List<ChallengeCheckin>>{};
    for (final c in checkins) {
      (byChallenge[c.challengeId] ??= []).add(c);
    }
    return [
      for (final c in challenges)
        ChallengeView(c, byChallenge[c.id] ?? const []),
    ];
  }

  Stream<List<ChallengeView>> watchAll() =>
      _db.watchTables({_db.challenges, _db.challengeCheckins}, _load);

  Future<void> save({
    int? id,
    required String title,
    String? description,
    required ChallengeMode mode,
    required int target,
    String? unit,
    required int startDay,
  }) async {
    final data = ChallengesCompanion(
      title: Value(title),
      description: Value(description),
      mode: Value(mode),
      target: Value(target),
      unit: Value(unit),
      startDay: Value(startDay),
    );
    if (id == null) {
      await _db.into(_db.challenges).insert(data);
    } else {
      await (_db.update(
        _db.challenges,
      )..where((c) => c.id.equals(id))).write(data);
      await _refreshCompletion(id, DateTime.now());
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.challenges)..where((c) => c.id.equals(id))).go();

  /// Grava o registro do dia ([amount] 0 apaga o registro).
  Future<void> setCheckin(
    int challengeId,
    int day,
    int amount, {
    DateTime? now,
  }) => _db.transaction(() async {
    await (_db.delete(_db.challengeCheckins)
          ..where((c) => c.challengeId.equals(challengeId) & c.day.equals(day)))
        .go();
    if (amount > 0) {
      await _db
          .into(_db.challengeCheckins)
          .insert(
            ChallengeCheckinsCompanion.insert(
              challengeId: challengeId,
              day: day,
              amount: Value(amount),
            ),
          );
    }
    await _refreshCompletion(challengeId, now ?? DateTime.now());
  });

  /// Marca como concluído ao atingir o alvo; desmarca se deixar de atingir.
  Future<void> _refreshCompletion(int id, DateTime now) async {
    final c = await (_db.select(
      _db.challenges,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (c == null) return;
    final checkins = await (_db.select(
      _db.challengeCheckins,
    )..where((x) => x.challengeId.equals(id))).get();
    final reached = challengeProgress(
      mode: c.mode,
      target: c.target,
      checkins: [for (final k in checkins) (k.day, k.amount)],
      today: 0,
    ).reached;
    if (reached && c.completedAt == null) {
      await (_db.update(_db.challenges)..where((x) => x.id.equals(id))).write(
        ChallengesCompanion(completedAt: Value(now)),
      );
    } else if (!reached && c.completedAt != null) {
      await (_db.update(_db.challenges)..where((x) => x.id.equals(id))).write(
        const ChallengesCompanion(completedAt: Value(null)),
      );
    }
  }
}

final challengesRepositoryProvider = Provider<ChallengesRepository>(
  (ref) => ChallengesRepository(ref.watch(databaseProvider)),
);

final challengesProvider = StreamProvider<List<ChallengeView>>(
  (ref) => ref.watch(challengesRepositoryProvider).watchAll(),
);
