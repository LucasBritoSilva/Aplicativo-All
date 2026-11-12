import 'package:aplicativo_all/features/gym/domain/gym_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fichas seguem A, B, C... sem limite', () {
    expect(nextSheetName(const []), 'Treino A');
    expect(nextSheetName(const ['Treino A', 'treino b']), 'Treino C');
    final many = [
      for (var i = 0; i < 26; i++) 'Treino ${String.fromCharCode(65 + i)}',
    ];
    expect(nextSheetName(many), 'Treino AA');
  });

  test('diferença para a meta de peso', () {
    expect(weightGap(null, 70), isNull);
    expect(weightGap(80, 75)!.label, '5 kg acima da meta');
    expect(weightGap(68.5, 70)!.label, '1,5 kg abaixo da meta');
    expect(weightGap(70.02, 70)!.reached, isTrue);
  });

  test('variação do peso no período', () {
    expect(weightChange(const [80]), isNull);
    expect(weightChange(const [80, 79, 77.5]), closeTo(-2.5, 1e-9));
  });

  test('descrição do exercício', () {
    expect(describeExercise(sets: 3, reps: '12', load: 40), '3 x 12 · 40 kg');
    expect(describeExercise(sets: 4, reps: '8-10', load: null), '4 x 8-10');
  });
}
