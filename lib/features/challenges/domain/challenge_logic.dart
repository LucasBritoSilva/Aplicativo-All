/// Progresso dos desafios pessoais. Interromper não apaga nada nem zera o
/// progresso: a sequência mostra só os dias seguidos atuais.
library;

import '../data/challenges_tables.dart';

class ChallengeProgress {
  const ChallengeProgress({
    required this.value,
    required this.target,
    required this.streak,
    required this.bestStreak,
    required this.activeDays,
  });

  /// Dias registrados (modo dias) ou soma das quantidades (modo quantidade).
  final int value;
  final int target;

  /// Dias seguidos com registro, terminando hoje ou ontem.
  final int streak;
  final int bestStreak;
  final int activeDays;

  double get fraction => target <= 0 ? 0 : (value / target).clamp(0.0, 1.0);

  int get percent => (fraction * 100).floor();

  bool get reached => target > 0 && value >= target;
}

/// [checkins] são (dia inteiro, quantidade). [today] também é dia inteiro.
ChallengeProgress challengeProgress({
  required ChallengeMode mode,
  required int target,
  required Iterable<(int, int)> checkins,
  required int today,
}) {
  final days = <int>{};
  var sum = 0;
  for (final (day, amount) in checkins) {
    if (amount <= 0) continue;
    days.add(day);
    sum += amount;
  }
  final sorted = days.toList()..sort();

  var best = 0, run = 0;
  int? prev;
  for (final d in sorted) {
    run = (prev != null && d == prev + 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }

  var streak = 0;
  var cursor = days.contains(today) ? today : today - 1;
  while (days.contains(cursor)) {
    streak++;
    cursor--;
  }

  return ChallengeProgress(
    value: mode == ChallengeMode.days ? days.length : sum,
    target: target,
    streak: streak,
    bestStreak: best,
    activeDays: days.length,
  );
}
