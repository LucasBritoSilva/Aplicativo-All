import '../../../core/utils/dates.dart';

/// Um item da rotina está feito somente se foi marcado no próprio dia.
bool isDoneToday({DateTime? doneOn, required DateTime today}) =>
    doneOn != null && isSameDay(doneOn, today);

/// Retorna os ids dos itens marcados em dias anteriores a [today],
/// que precisam voltar a "não feito" (reset diário).
List<int> routineItemsToReset(
  Iterable<({int id, DateTime? doneOn})> items,
  DateTime today,
) {
  final startOfToday = dateOnly(today);
  return [
    for (final item in items)
      if (item.doneOn != null && dateOnly(item.doneOn!).isBefore(startOfToday))
        item.id,
  ];
}
