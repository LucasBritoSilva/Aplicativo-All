import 'package:app_pessoal/core/utils/dates.dart';
import 'package:app_pessoal/features/agenda/domain/agenda_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 11, 11);

  test('evento sem fim aparece só no dia em que começa', () {
    final start = DateTime(2026, 11, 11, 14);
    expect(eventOnDay(startsAt: start, day: day), isTrue);
    expect(eventOnDay(startsAt: start, day: DateTime(2026, 11, 12)), isFalse);
    expect(eventOnDay(startsAt: start, day: DateTime(2026, 11, 10)), isFalse);
  });

  test('evento que atravessa a meia-noite aparece nos dois dias', () {
    final start = DateTime(2026, 11, 11, 22);
    final end = DateTime(2026, 11, 12, 2);
    expect(eventOnDay(startsAt: start, endsAt: end, day: day), isTrue);
    expect(
      eventOnDay(startsAt: start, endsAt: end, day: DateTime(2026, 11, 12)),
      isTrue,
    );
  });

  test('terminar exatamente à meia-noite não conta para o dia seguinte', () {
    final start = DateTime(2026, 11, 11, 20);
    final end = DateTime(2026, 11, 12);
    expect(
      eventOnDay(startsAt: start, endsAt: end, day: DateTime(2026, 11, 12)),
      isFalse,
    );
  });

  test('semana começa na segunda-feira', () {
    expect(startOfWeek(DateTime(2026, 11, 11)), DateTime(2026, 11, 9));
    expect(startOfWeek(DateTime(2026, 11, 15, 23)), DateTime(2026, 11, 9));
    expect(startOfWeek(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    expect(daysOfWeek(day).last, DateTime(2026, 11, 15));
  });
}
