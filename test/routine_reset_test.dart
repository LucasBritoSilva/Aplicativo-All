import 'package:aplicativo_all/features/routine/domain/routine_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 11, 9, 30);

  group('isDoneToday', () {
    test('item nunca marcado não está feito', () {
      expect(isDoneToday(doneOn: null, today: today), isFalse);
    });

    test('item marcado hoje está feito (a hora não importa)', () {
      expect(
        isDoneToday(doneOn: DateTime(2026, 11, 11, 23, 59), today: today),
        isTrue,
      );
      expect(isDoneToday(doneOn: DateTime(2026, 11, 11), today: today), isTrue);
    });

    test('item marcado ontem volta a não feito no dia seguinte', () {
      expect(
        isDoneToday(doneOn: DateTime(2026, 11, 10, 22), today: today),
        isFalse,
      );
    });

    test('virada de mês e de ano', () {
      expect(
        isDoneToday(
          doneOn: DateTime(2026, 12, 31, 20),
          today: DateTime(2027, 1, 1, 0, 1),
        ),
        isFalse,
      );
    });
  });

  group('routineItemsToReset', () {
    test('reseta só itens marcados em dias anteriores', () {
      final items = [
        (id: 1, doneOn: null),
        (id: 2, doneOn: DateTime(2026, 11, 11, 7)),
        (id: 3, doneOn: DateTime(2026, 11, 10, 23, 59)),
        (id: 4, doneOn: DateTime(2026, 10, 1)),
      ];
      expect(routineItemsToReset(items, today), [3, 4]);
    });

    test('lista vazia ou tudo de hoje não reseta nada', () {
      expect(routineItemsToReset(const [], today), isEmpty);
      expect(
        routineItemsToReset([(id: 1, doneOn: DateTime(2026, 11, 11))], today),
        isEmpty,
      );
    });

    test('após o reset, o item deixa de contar como feito', () {
      final doneYesterday = DateTime(2026, 11, 10, 8);
      final ids = routineItemsToReset([(id: 7, doneOn: doneYesterday)], today);
      expect(ids, [7]);
      // Depois do reset o valor gravado passa a ser nulo:
      expect(isDoneToday(doneOn: null, today: today), isFalse);
    });
  });
}
