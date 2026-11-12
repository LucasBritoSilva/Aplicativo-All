import '../../../core/utils/dates.dart';

/// Diz se um evento aparece no dia [day].
///
/// Sem horário de fim, o evento conta só no dia em que começa. Com fim,
/// aparece em todos os dias que atravessa (terminar exatamente à
/// meia-noite não conta para o dia seguinte).
bool eventOnDay({
  required DateTime startsAt,
  DateTime? endsAt,
  required DateTime day,
}) {
  final dayStart = dateOnly(day);
  final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
  if (!startsAt.isBefore(dayEnd)) return false;
  if (endsAt == null || !endsAt.isAfter(startsAt)) {
    return !startsAt.isBefore(dayStart);
  }
  return endsAt.isAfter(dayStart);
}
