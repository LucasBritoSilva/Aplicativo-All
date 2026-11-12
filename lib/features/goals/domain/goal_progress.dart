import '../../../core/utils/dates.dart';

/// Fração concluída de uma meta (entre 0 e 1).
///
/// Valor-alvo zero ou negativo resulta em 0. Valores acima do alvo
/// resultam em 1 (meta cumprida).
double goalProgress({required double current, required double target}) {
  if (target <= 0 || current <= 0) return 0;
  final f = current / target;
  return f > 1 ? 1 : f;
}

/// Percentual inteiro, arredondado para baixo: 99,6% aparece como 99%,
/// para só mostrar 100% quando a meta foi de fato alcançada.
int goalPercent({required double current, required double target}) =>
    (goalProgress(current: current, target: target) * 100).floor();

bool goalReached({required double current, required double target}) =>
    target > 0 && current >= target;

/// Dias até a data-limite (negativo se já passou). Nulo sem data.
int? daysUntilDeadline({DateTime? deadline, required DateTime today}) {
  if (deadline == null) return null;
  return daysBetween(today, deadline);
}
