import '../../../core/utils/dates.dart';

/// Progresso de um hábito dentro de uma semana (segunda a domingo).
class WeekProgress {
  const WeekProgress({required this.done, required this.target});

  /// Dias distintos da semana em que o hábito foi feito.
  final int done;

  /// Meta semanal (ex.: 3 vezes por semana).
  final int target;

  /// Fração entre 0 e 1 para a barra de progresso.
  double get fraction {
    if (target <= 0) return 0;
    final f = done / target;
    return f > 1 ? 1 : f;
  }

  bool get achieved => target > 0 && done >= target;

  /// Quantas vezes ainda faltam nesta semana (nunca negativo).
  int get remaining => achieved ? 0 : target - done;
}

/// Calcula o progresso da semana que contém [today].
///
/// [checks] são os dias marcados (a hora é ignorada). Marcações repetidas
/// no mesmo dia contam uma vez só, e dias fora da semana são ignorados.
WeekProgress habitWeekProgress({
  required Iterable<DateTime> checks,
  required int weeklyTarget,
  required DateTime today,
}) {
  final start = startOfWeek(today);
  final end = DateTime(start.year, start.month, start.day + 7);
  final days = <DateTime>{};
  for (final c in checks) {
    final d = dateOnly(c);
    if (!d.isBefore(start) && d.isBefore(end)) days.add(d);
  }
  return WeekProgress(done: days.length, target: weeklyTarget);
}
