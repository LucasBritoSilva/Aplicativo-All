/// Regras simples da academia. A meta de peso é só um número escolhido
/// pelo usuário: o app não sugere metas nem dá orientação de saúde.
library;

import '../../../core/utils/dates.dart';

/// Próximo nome de ficha: "Treino A", "Treino B", ... "Treino Z",
/// "Treino AA"... (sem limite).
String nextSheetName(Iterable<String> existing) {
  final used = existing.map((e) => e.trim().toUpperCase()).toSet();
  for (var i = 0; ; i++) {
    final name = 'Treino ${_letters(i)}';
    if (!used.contains(name.toUpperCase())) return name;
  }
}

String _letters(int index) {
  var n = index;
  var out = '';
  do {
    out = String.fromCharCode(65 + n % 26) + out;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return out;
}

/// Diferença entre o peso atual e a meta.
class WeightGap {
  const WeightGap(this.kg);

  /// Positivo: acima da meta. Negativo: abaixo. Zero: na meta.
  final double kg;

  bool get reached => kg.abs() < 0.05;

  String get label {
    if (reached) return 'Meta atingida';
    final v = formatNumber(double.parse(kg.abs().toStringAsFixed(1)));
    return kg > 0 ? '$v kg acima da meta' : '$v kg abaixo da meta';
  }
}

WeightGap? weightGap(double? current, double? goal) =>
    current == null || goal == null ? null : WeightGap(current - goal);

/// Variação entre o primeiro e o último registro do período.
double? weightChange(List<double> ordered) =>
    ordered.length < 2 ? null : ordered.last - ordered.first;

/// "3 x 12 · 40 kg"
String describeExercise({
  required int sets,
  required String reps,
  required double? load,
}) => '$sets x $reps${load == null ? '' : ' · ${formatNumber(load)} kg'}';
