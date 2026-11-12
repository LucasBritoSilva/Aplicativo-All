import 'package:app_pessoal/features/goals/domain/goal_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goalProgress', () {
    test('valor atual sobre valor-alvo', () {
      expect(goalProgress(current: 25, target: 100), 0.25);
      expect(goalProgress(current: 1.5, target: 3), 0.5);
    });

    test('limita entre 0 e 1', () {
      expect(goalProgress(current: 150, target: 100), 1.0);
      expect(goalProgress(current: -10, target: 100), 0.0);
    });

    test('alvo zero ou negativo resulta em 0', () {
      expect(goalProgress(current: 10, target: 0), 0.0);
      expect(goalProgress(current: 10, target: -5), 0.0);
    });

    test('percentual arredonda para baixo', () {
      expect(goalPercent(current: 996, target: 1000), 99);
      expect(goalPercent(current: 1000, target: 1000), 100);
      expect(goalPercent(current: 1, target: 3), 33);
      expect(goalPercent(current: 0, target: 3), 0);
    });

    test('meta alcançada', () {
      expect(goalReached(current: 100, target: 100), isTrue);
      expect(goalReached(current: 99.9, target: 100), isFalse);
      expect(goalReached(current: 5, target: 0), isFalse);
    });
  });

  group('daysUntilDeadline', () {
    final today = DateTime(2026, 11, 11, 18);
    test('data opcional', () {
      expect(daysUntilDeadline(deadline: null, today: today), isNull);
    });
    test('conta dias de calendário', () {
      expect(
        daysUntilDeadline(deadline: DateTime(2026, 11, 11), today: today),
        0,
      );
      expect(
        daysUntilDeadline(deadline: DateTime(2026, 12, 31), today: today),
        50,
      );
      expect(
        daysUntilDeadline(deadline: DateTime(2026, 11, 1), today: today),
        -10,
      );
    });
  });
}
