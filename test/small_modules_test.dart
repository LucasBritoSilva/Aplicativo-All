import 'dart:math';

import 'package:aplicativo_all/core/navigation/recent_modules.dart';
import 'package:aplicativo_all/core/utils/text.dart';
import 'package:aplicativo_all/features/app_limits/domain/app_limits_logic.dart';
import 'package:aplicativo_all/features/break_timer/domain/break_logic.dart';
import 'package:aplicativo_all/features/challenges/data/challenges_tables.dart';
import 'package:aplicativo_all/features/challenges/domain/challenge_logic.dart';
import 'package:aplicativo_all/features/counters/domain/counter_logic.dart';
import 'package:aplicativo_all/features/decider/domain/decider_logic.dart';
import 'package:aplicativo_all/features/priorities/data/priorities_repository.dart';
import 'package:aplicativo_all/features/stats/data/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seis módulos recentes', () {
    test('o aberto vai para o primeiro lugar, sem duplicar', () {
      var list = <String>[];
      for (final id in ['a', 'b', 'c']) {
        list = pushRecentModule(list, id);
      }
      expect(list, ['c', 'b', 'a']);
      list = pushRecentModule(list, 'a');
      expect(list, ['a', 'c', 'b']);
    });

    test('o sétimo módulo diferente tira o mais antigo', () {
      var list = <String>[];
      for (final id in ['1', '2', '3', '4', '5', '6']) {
        list = pushRecentModule(list, id);
      }
      expect(list, ['6', '5', '4', '3', '2', '1']);
      list = pushRecentModule(list, '7');
      expect(list, ['7', '6', '5', '4', '3', '2']);
      expect(list, hasLength(6));
    });

    test('lista gravada é lida com segurança', () {
      const valid = {'a', 'b', 'c'};
      expect(parseRecentModules(null, valid), isEmpty);
      expect(parseRecentModules('lixo', valid), isEmpty);
      expect(parseRecentModules('{"a":1}', valid), isEmpty);
      expect(parseRecentModules('["b","x","b","a"]', valid), ['b', 'a']);
    });

    test('sugestões completam a grade sem repetir recentes', () {
      expect(suggestedModules(const [], const ['a', 'b']), ['a', 'b']);
      expect(
        suggestedModules(
          const ['b'],
          const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        ),
        ['a', 'c', 'd', 'e', 'f'],
      );
      expect(
        suggestedModules(const ['1', '2', '3', '4', '5', '6'], const ['a']),
        isEmpty,
      );
    });
  });

  group('contador de dias', () {
    test('futuro, hoje e passado sem números negativos', () {
      expect(countDays(110, 100).label, 'Faltam 10 dias');
      expect(countDays(101, 100).label, 'Falta 1 dia');
      expect(countDays(100, 100).label, 'É hoje!');
      expect(countDays(99, 100).label, 'Há 1 dia');
      final past = countDays(70, 100);
      expect(past.days, 30);
      expect(past.direction, CounterDirection.past);
    });

    test('ordem: hoje, próximos e depois passados', () {
      final days = [90, 100, 130, 105, 50]
        ..sort((a, b) => compareCounters(a, b, 100));
      expect(days, [100, 105, 130, 90, 50]);
    });
  });

  group('desafios', () {
    test('modo dias conta dias distintos e a sequência atual', () {
      final p = challengeProgress(
        mode: ChallengeMode.days,
        target: 10,
        checkins: const [(1, 1), (2, 1), (3, 1), (5, 1), (6, 1)],
        today: 6,
      );
      expect(p.value, 5);
      expect(p.percent, 50);
      expect(p.streak, 2);
      expect(p.bestStreak, 3);
    });

    test('sequência vale até ontem e interromper não apaga o progresso', () {
      final p = challengeProgress(
        mode: ChallengeMode.days,
        target: 3,
        checkins: const [(1, 1), (2, 1), (3, 1)],
        today: 10,
      );
      expect(p.streak, 0);
      expect(p.value, 3);
      expect(p.reached, isTrue);
      expect(
        challengeProgress(
          mode: ChallengeMode.days,
          target: 3,
          checkins: const [(8, 1), (9, 1)],
          today: 10,
        ).streak,
        2,
      );
    });

    test('modo quantidade soma os registros', () {
      final p = challengeProgress(
        mode: ChallengeMode.count,
        target: 500,
        checkins: const [(1, 120), (2, 80)],
        today: 2,
      );
      expect(p.value, 200);
      expect(p.percent, 40);
    });
  });

  group('prioridades', () {
    test('reordenar move para a posição final escolhida', () {
      expect(reorderIds([1, 2, 3], 0, 2), [2, 3, 1]);
      expect(reorderIds([1, 2, 3], 2, 0), [3, 1, 2]);
      expect(reorderIds([1, 2, 3], 1, 1), [1, 2, 3]);
    });
  });

  group('pausas', () {
    final t0 = DateTime(2026, 11, 12, 9);

    test('iniciar, pausar e continuar mantêm o tempo restante', () {
      var s = const BreakState(focusMinutes: 25, restMinutes: 5).start(t0);
      expect(s.remaining(t0.add(const Duration(minutes: 10))), 15 * 60);
      s = s.pause(t0.add(const Duration(minutes: 10)));
      // Pausado não perde tempo, mesmo uma hora depois.
      expect(s.remaining(t0.add(const Duration(hours: 1))), 15 * 60);
      s = s.resume(t0.add(const Duration(hours: 1)));
      expect(
        s.remaining(t0.add(const Duration(hours: 1, minutes: 5))),
        10 * 60,
      );
    });

    test('estado sobrevive a gravar e ler de novo', () {
      final s = const BreakState(focusMinutes: 30, restMinutes: 7).start(t0);
      final back = BreakState.decode(s.encode());
      expect(back.status, BreakStatus.running);
      expect(back.endsAt, s.endsAt);
      expect(back.remaining(t0.add(const Duration(minutes: 1))), 29 * 60);
      expect(BreakState.decode('não é json').status, BreakStatus.idle);
    });

    test('fim do foco conta um ciclo e passa para a pausa', () {
      var s = const BreakState(focusMinutes: 1, restMinutes: 1).start(t0);
      expect(s.finished(t0.add(const Duration(minutes: 2))), isTrue);
      s = s.next(100, completed: true);
      expect(s.phase, BreakPhase.rest);
      expect(s.cyclesOn(100), 1);
      expect(s.cyclesOn(101), 0);
      s = s.next(100, completed: true).next(100, completed: false);
      expect(s.cyclesOn(100), 1);
    });

    test('reiniciar volta ao início do período', () {
      final s = const BreakState(focusMinutes: 20).start(t0).reset();
      expect(s.status, BreakStatus.idle);
      expect(s.remaining(t0), 20 * 60);
    });
  });

  group('decisor', () {
    test('valida o intervalo', () {
      expect(validateRange(null, 5), isNotNull);
      expect(validateRange(10, 5), isNotNull);
      expect(validateRange(5, 5), isNull);
    });

    test('número sorteado fica dentro do intervalo', () {
      final r = Random(7);
      for (var i = 0; i < 200; i++) {
        final n = drawNumber(-3, 3, r);
        expect(n, inInclusiveRange(-3, 3));
      }
      expect(drawNumber(4, 4, r), 4);
    });

    test('opções por linha, vírgula ou ponto e vírgula', () {
      expect(parseOptions('pizza\n sushi ,, hambúrguer;  '), [
        'pizza',
        'sushi',
        'hambúrguer',
      ]);
      expect(drawOption(['única']), 'única');
    });
  });

  group('limite de apps', () {
    test('tempo restante e excesso', () {
      const s = LimitStatus(usedMs: 20 * 60000, limitMinutes: 30);
      expect(s.remainingMs, 10 * 60000);
      expect(s.exceeded, isFalse);
      const over = LimitStatus(usedMs: 35 * 60000, limitMinutes: 30);
      expect(over.remainingMs, 0);
      expect(over.overMs, 5 * 60000);
      expect(over.fraction, 1);
    });

    test('formato do tempo de uso', () {
      expect(formatUsage(0), '0min');
      expect(formatUsage(30000), 'menos de 1min');
      expect(formatUsage(65 * 60000), '1h 05min');
      expect(formatUsage(120 * 60000), '2h');
    });

    test('modo de cada limite ativo vai para o monitor', () {
      expect(
        activeModes(const [
          (packageName: 'a', limitMinutes: 30, enabled: true, mode: 'notify'),
          (packageName: 'b', limitMinutes: 10, enabled: false, mode: 'overlay'),
          (packageName: 'c', limitMinutes: 5, enabled: true, mode: 'overlay'),
        ]),
        {'a': 'notify', 'c': 'overlay'},
      );
    });

    test('só limites ativos vão para o monitor', () {
      expect(
        activeLimits(const [
          (packageName: 'a', limitMinutes: 30, enabled: true),
          (packageName: 'b', limitMinutes: 10, enabled: false),
        ]),
        {'a': 30},
      );
    });
  });

  group('busca e telefone', () {
    test('busca ignora acentos e maiúsculas', () {
      expect(matchesQuery('acucar', ['Açúcar mascavo']), isTrue);
      expect(matchesQuery('', [null]), isTrue);
      expect(matchesQuery('xyz', ['abc', null]), isFalse);
    });

    test('número do WhatsApp com código do Brasil', () {
      expect(whatsAppNumber('(11) 98765-4321'), '5511987654321');
      expect(whatsAppNumber('+351 912 345 678'), '351912345678');
      expect(whatsAppNumber('123'), isNull);
    });
  });

  group('estatísticas', () {
    test('constância dos hábitos pelas metas semanais', () {
      // Semana de 09/11/2026 (segunda) a 15/11.
      final c = habitConstancy(
        habits: const [(id: 1, weeklyTarget: 2), (id: 2, weeklyTarget: 4)],
        checks: [
          (habitId: 1, day: DateTime(2026, 11, 9)),
          (habitId: 1, day: DateTime(2026, 11, 10)),
          (habitId: 1, day: DateTime(2026, 11, 11)),
          (habitId: 2, day: DateTime(2026, 11, 9)),
        ],
        from: DateTime(2026, 11, 9),
        to: DateTime(2026, 11, 15),
      );
      // Hábito 1: 100% (limitado). Hábito 2: 1 de 4 = 25%. Média 62,5%.
      expect(c, closeTo(0.625, 1e-9));
    });

    test('sem hábitos não há indicador', () {
      expect(
        habitConstancy(
          habits: const [],
          checks: const [],
          from: DateTime(2026, 11, 9),
          to: DateTime(2026, 11, 15),
        ),
        isNull,
      );
    });
  });
}
