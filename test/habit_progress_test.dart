import 'package:app_pessoal/features/habits/domain/habit_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Quarta-feira, 11/11/2026. A semana vai de seg 09/11 a dom 15/11.
  final today = DateTime(2026, 11, 11, 15);

  group('habitWeekProgress', () {
    test('conta só os dias da semana corrente (segunda a domingo)', () {
      final p = habitWeekProgress(
        checks: [
          DateTime(2026, 11, 8), // domingo da semana anterior
          DateTime(2026, 11, 9), // segunda
          DateTime(2026, 11, 11), // quarta
          DateTime(2026, 11, 15, 23, 59), // domingo desta semana
          DateTime(2026, 11, 16), // segunda da próxima semana
        ],
        weeklyTarget: 3,
        today: today,
      );
      expect(p.done, 3);
      expect(p.target, 3);
      expect(p.fraction, 1.0);
      expect(p.achieved, isTrue);
      expect(p.remaining, 0);
    });

    test('meta "3 vezes por semana" com 2 feitas = 2/3', () {
      final p = habitWeekProgress(
        checks: [DateTime(2026, 11, 9), DateTime(2026, 11, 10)],
        weeklyTarget: 3,
        today: today,
      );
      expect(p.done, 2);
      expect(p.fraction, closeTo(2 / 3, 1e-9));
      expect(p.achieved, isFalse);
      expect(p.remaining, 1);
    });

    test('marcações repetidas no mesmo dia contam uma vez', () {
      final p = habitWeekProgress(
        checks: [DateTime(2026, 11, 10, 8), DateTime(2026, 11, 10, 20)],
        weeklyTarget: 2,
        today: today,
      );
      expect(p.done, 1);
      expect(p.fraction, 0.5);
    });

    test('passar da meta não ultrapassa 100%', () {
      final p = habitWeekProgress(
        checks: [
          for (var d = 9; d <= 15; d++) DateTime(2026, 11, d),
        ],
        weeklyTarget: 3,
        today: today,
      );
      expect(p.done, 7);
      expect(p.fraction, 1.0);
      expect(p.remaining, 0);
    });

    test('sem marcações = 0%', () {
      final p = habitWeekProgress(
        checks: const [],
        weeklyTarget: 5,
        today: today,
      );
      expect(p.done, 0);
      expect(p.fraction, 0);
      expect(p.remaining, 5);
    });

    test('meta zero não divide por zero', () {
      final p = habitWeekProgress(
        checks: [DateTime(2026, 11, 9)],
        weeklyTarget: 0,
        today: today,
      );
      expect(p.fraction, 0);
      expect(p.achieved, isFalse);
    });

    test('domingo pertence à semana que começou na segunda anterior', () {
      final sunday = DateTime(2026, 11, 15, 10);
      final p = habitWeekProgress(
        checks: [DateTime(2026, 11, 9), DateTime(2026, 11, 16)],
        weeklyTarget: 2,
        today: sunday,
      );
      expect(p.done, 1);
    });

    test('semana que atravessa a virada de mês', () {
      // Sábado 02/01/2027 -> semana de seg 28/12/2026 a dom 03/01/2027.
      final p = habitWeekProgress(
        checks: [
          DateTime(2026, 12, 27), // domingo anterior: fora
          DateTime(2026, 12, 28),
          DateTime(2026, 12, 31),
          DateTime(2027, 1, 3),
        ],
        weeklyTarget: 4,
        today: DateTime(2027, 1, 2),
      );
      expect(p.done, 3);
    });
  });
}
