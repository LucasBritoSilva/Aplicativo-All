/// Contagem de dias entre hoje e uma data, sempre em dias de calendário
/// (sem horas), então a mudança de dia e o horário de verão não afetam.
library;

enum CounterDirection { future, today, past }

class DayCount {
  const DayCount(this.direction, this.days);

  final CounterDirection direction;

  /// Sempre positivo (ou zero): quantos dias faltam ou já passaram.
  final int days;

  /// "Faltam 12 dias", "É hoje!", "Há 1 dia".
  String get label => switch (direction) {
    CounterDirection.today => 'É hoje!',
    CounterDirection.future => days == 1 ? 'Falta 1 dia' : 'Faltam $days dias',
    CounterDirection.past => days == 1 ? 'Há 1 dia' : 'Há $days dias',
  };
}

/// [targetDay] e [today] são dias inteiros (dias desde 01/01/1970).
DayCount countDays(int targetDay, int today) {
  final diff = targetDay - today;
  if (diff == 0) return const DayCount(CounterDirection.today, 0);
  return diff > 0
      ? DayCount(CounterDirection.future, diff)
      : DayCount(CounterDirection.past, -diff);
}

/// Ordem da lista: hoje, depois os próximos (mais perto primeiro), depois
/// os passados (mais recente primeiro).
int compareCounters(int dayA, int dayB, int today) {
  int group(int d) => d == today ? 0 : (d > today ? 1 : 2);
  final ga = group(dayA), gb = group(dayB);
  if (ga != gb) return ga.compareTo(gb);
  return ga == 2 ? dayB.compareTo(dayA) : dayA.compareTo(dayB);
}
