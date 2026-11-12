import 'package:aplicativo_all/core/utils/dates.dart';
import 'package:aplicativo_all/features/routine/data/routine_tables.dart';
import 'package:aplicativo_all/features/routine/domain/routine_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 09/11/2026 é uma segunda-feira (o exemplo da especificação).
  final monday = epochDay(DateTime(2026, 11, 9));
  final monWedFri = maskOf([1, 3, 5]);

  group('dias da semana', () {
    test('o número do dia bate com o dia da semana real', () {
      expect(weekdayOfEpochDay(monday), DateTime.monday);
      expect(weekdayOfEpochDay(monday + 6), DateTime.sunday);
      expect(dateFromEpochDay(monday), DateTime(2026, 11, 9));
    });

    test('máscara guarda qualquer combinação de dias', () {
      expect(weekdaysOf(monWedFri), [1, 3, 5]);
      expect(maskHasWeekday(monWedFri, 2), isFalse);
      expect(describeWeekdays(monWedFri), 'seg, qua, sex');
      expect(describeWeekdays(allWeekdaysMask), 'Todos os dias');
      expect(describeWeekdays(workdaysMask), 'Segunda a sexta');
    });

    test('atividade semanal só ocorre nos dias escolhidos', () {
      bool on(int day) => activityOccursOn(
        weekdays: monWedFri,
        singleDay: null,
        startDay: monday,
        archivedDay: null,
        day: day,
      );
      expect(on(monday), isTrue);
      expect(on(monday + 1), isFalse);
      expect(on(monday + 2), isTrue);
      expect(on(monday + 4), isTrue);
      expect(on(monday + 5), isFalse);
      // Antes do início do planejamento não há ocorrência.
      expect(on(monday - 7), isFalse);
    });

    test('data única ocorre só naquele dia; arquivada para de ocorrer', () {
      expect(
        activityOccursOn(
          weekdays: 0,
          singleDay: monday + 3,
          startDay: monday,
          archivedDay: null,
          day: monday + 3,
        ),
        isTrue,
      );
      expect(
        activityOccursOn(
          weekdays: 0,
          singleDay: monday + 3,
          startDay: monday,
          archivedDay: null,
          day: monday + 10,
        ),
        isFalse,
      );
      expect(
        activityOccursOn(
          weekdays: allWeekdaysMask,
          singleDay: null,
          startDay: monday,
          archivedDay: monday + 2,
          day: monday + 2,
        ),
        isFalse,
      );
    });

    test('validação do cadastro', () {
      expect(
        validateActivity(
          name: ' ',
          startMinute: 60,
          endMinute: 120,
          weekdays: 1,
          singleDay: null,
        ),
        isNotNull,
      );
      expect(
        validateActivity(
          name: 'Ler',
          startMinute: 120,
          endMinute: 120,
          weekdays: 1,
          singleDay: null,
        ),
        isNotNull,
      );
      expect(
        validateActivity(
          name: 'Ler',
          startMinute: 60,
          endMinute: 120,
          weekdays: 0,
          singleDay: null,
        ),
        isNotNull,
      );
      expect(
        validateActivity(
          name: 'Ler',
          startMinute: 60,
          endMinute: 120,
          weekdays: 0,
          singleDay: monday,
        ),
        isNull,
      );
    });
  });

  group('tolerância de atraso', () {
    DisplayState at(
      DateTime now, {
      OccurrenceStatus status = OccurrenceStatus.pending,
      ActivityKind kind = ActivityKind.flexible,
      bool rescheduled = false,
    }) => displayState(
      status: status,
      kind: kind,
      rescheduled: rescheduled,
      scheduledDay: monday,
      scheduledStart: 14 * 60,
      toleranceMinutes: 15,
      now: now,
    );

    test('às 14h está no horário; até 14h15 segue dentro da tolerância', () {
      expect(at(DateTime(2026, 11, 9, 13, 0)), DisplayState.pending);
      expect(at(DateTime(2026, 11, 9, 14, 0)), DisplayState.pending);
      expect(at(DateTime(2026, 11, 9, 14, 15)), DisplayState.pending);
    });

    test('depois de 14h15 sem iniciar, passa a atrasada', () {
      expect(at(DateTime(2026, 11, 9, 14, 15, 1)), DisplayState.late);
      expect(at(DateTime(2026, 11, 10, 8, 0)), DisplayState.late);
    });

    test('atrasada não vira "não realizada" sozinha', () {
      // Uma semana depois o estado gravado continua pendente: o app só
      // mostra "Atrasada" e espera a decisão do usuário.
      expect(at(DateTime(2026, 11, 16, 9, 0)), DisplayState.late);
    });

    test('quem já começou não fica atrasado', () {
      final late = DateTime(2026, 11, 9, 18, 0);
      expect(
        at(late, status: OccurrenceStatus.inProgress),
        DisplayState.inProgress,
      );
      expect(at(late, status: OccurrenceStatus.paused), DisplayState.paused);
      expect(at(late, status: OccurrenceStatus.done), DisplayState.done);
      expect(
        at(late, status: OccurrenceStatus.awaitingResume),
        DisplayState.awaitingResume,
      );
    });

    test('descanso nunca fica atrasado', () {
      expect(
        at(DateTime(2026, 11, 9, 20, 0), kind: ActivityKind.rest),
        DisplayState.pending,
      );
    });

    test('reagendada aparece como reagendada até atrasar', () {
      expect(
        at(DateTime(2026, 11, 9, 13, 0), rescheduled: true),
        DisplayState.rescheduled,
      );
      expect(
        at(DateTime(2026, 11, 9, 15, 0), rescheduled: true),
        DisplayState.late,
      );
    });
  });

  group('ações permitidas', () {
    test('pendente: iniciar, concluir, reagendar ou não realizada', () {
      expect(allowedActions(OccurrenceStatus.pending), {
        OccurrenceAction.start,
        OccurrenceAction.conclude,
        OccurrenceAction.markNotDone,
        OccurrenceAction.reschedule,
      });
    });

    test('em andamento não pode ser reagendada nem "não realizada"', () {
      final a = allowedActions(OccurrenceStatus.inProgress);
      expect(a, contains(OccurrenceAction.pause));
      expect(a, contains(OccurrenceAction.continueLater));
      expect(a, isNot(contains(OccurrenceAction.markNotDone)));
      expect(a, isNot(contains(OccurrenceAction.reschedule)));
    });

    test('aguardando retomada: continuar, reagendar, parcial ou concluir', () {
      expect(allowedActions(OccurrenceStatus.awaitingResume), {
        OccurrenceAction.start,
        OccurrenceAction.continueLater,
        OccurrenceAction.closePartial,
        OccurrenceAction.conclude,
      });
    });

    test('encerrada só pode ser reaberta', () {
      for (final s in [
        OccurrenceStatus.done,
        OccurrenceStatus.partial,
        OccurrenceStatus.notDone,
      ]) {
        expect(allowedActions(s), {OccurrenceAction.reopen});
      }
    });

    test('descanso só pode ser movido', () {
      expect(
        allowedActions(OccurrenceStatus.pending, kind: ActivityKind.rest),
        {OccurrenceAction.reschedule},
      );
    });
  });

  group('cronômetro', () {
    final t0 = DateTime(2026, 11, 9, 14, 0);

    test('soma o acumulado com o trecho em andamento', () {
      expect(
        sessionSeconds(
          accumulatedSeconds: 600,
          runningSince: t0,
          now: t0.add(const Duration(minutes: 5)),
        ),
        900,
      );
    });

    test('pausada não soma tempo', () {
      expect(
        sessionSeconds(
          accumulatedSeconds: 600,
          runningSince: null,
          now: t0.add(const Duration(hours: 3)),
        ),
        600,
      );
    });

    test('relógio que volta no tempo não gera tempo negativo', () {
      expect(
        sessionSeconds(
          accumulatedSeconds: 600,
          runningSince: t0,
          now: t0.subtract(const Duration(hours: 1)),
        ),
        600,
      );
    });

    test('planejado 60 min, realizado 25: restam 35', () {
      final planned = plannedSeconds(14 * 60, 15 * 60);
      expect(planned, 3600);
      expect(remainingSeconds(planned, 25 * 60), 35 * 60);
      expect(remainingSeconds(planned, 70 * 60), 0);
    });
  });

  group('conflitos', () {
    const college = TimeBlock(
      id: 1,
      name: 'Faculdade',
      kind: ActivityKind.fixed,
      day: 100,
      start: 19 * 60,
      end: 22 * 60,
    );
    const rest = TimeBlock(
      id: 2,
      name: 'Descanso',
      kind: ActivityKind.rest,
      day: 100,
      start: 12 * 60,
      end: 13 * 60,
    );

    test('sobreposição com compromisso fixo é apontada', () {
      final c = findConflicts(
        day: 100,
        start: 21 * 60,
        end: 23 * 60,
        blocks: [college, rest],
      );
      expect(c.map((b) => b.name), ['Faculdade']);
      expect(describeConflict(c.single), contains('compromisso fixo'));
    });

    test('descanso também conta na verificação', () {
      final c = findConflicts(
        day: 100,
        start: 12 * 60 + 30,
        end: 14 * 60,
        blocks: [college, rest],
      );
      expect(c.single.name, 'Descanso');
    });

    test('encostar no horário não é conflito', () {
      expect(
        findConflicts(
          day: 100,
          start: 22 * 60,
          end: 23 * 60,
          blocks: [college],
        ),
        isEmpty,
      );
      expect(
        findConflicts(
          day: 100,
          start: 18 * 60,
          end: 19 * 60,
          blocks: [college],
        ),
        isEmpty,
      );
    });

    test('outro dia e a própria ocorrência não contam', () {
      expect(
        findConflicts(day: 101, start: 0, end: 1439, blocks: [college]),
        isEmpty,
      );
      expect(
        findConflicts(
          day: 100,
          start: 19 * 60,
          end: 20 * 60,
          blocks: [college],
          ignoreId: 1,
        ),
        isEmpty,
      );
    });

    test('planejamentos se sobrepõem só em dias em comum', () {
      bool overlap(int maskB, {int? singleB}) => plansOverlap(
        startA: 14 * 60,
        endA: 15 * 60,
        weekdaysA: monWedFri,
        singleDayA: null,
        startB: 14 * 60 + 30,
        endB: 16 * 60,
        weekdaysB: maskB,
        singleDayB: singleB,
      );
      expect(overlap(maskOf([1])), isTrue);
      expect(overlap(maskOf([2, 4])), isFalse);
      expect(overlap(0, singleB: monday), isTrue);
      expect(overlap(0, singleB: monday + 1), isFalse);
    });
  });

  group('Lista de Retomadas', () {
    test('mais antigas primeiro; o id desempata', () {
      final entries = [
        (id: 3, enteredAt: DateTime(2026, 11, 11)),
        (id: 1, enteredAt: DateTime(2026, 11, 9)),
        (id: 2, enteredAt: DateTime(2026, 11, 10)),
        (id: 4, enteredAt: DateTime(2026, 11, 10)),
      ]..sort(compareResumeEntries);
      expect(entries.map((e) => e.id), [1, 2, 4, 3]);
    });
  });

  group('notificações', () {
    final now = DateTime(2026, 11, 9, 12, 0);

    NotifiableOccurrence occ(
      int id, {
      OccurrenceStatus status = OccurrenceStatus.pending,
      ActivityKind kind = ActivityKind.flexible,
      int dayOffset = 0,
      int start = 14 * 60,
      int? continuationDay,
      int? continuationStart,
    }) => NotifiableOccurrence(
      id: id,
      name: 'Estudar programação',
      kind: kind,
      status: status,
      scheduledDay: monday + dayOffset,
      scheduledStart: start,
      continuationDay: continuationDay,
      continuationStart: continuationStart,
    );

    test('uma única notificação, no horário de início', () {
      final plan = planRoutineNotifications(occurrences: [occ(1)], now: now);
      expect(plan, hasLength(1));
      expect(plan.single.when, DateTime(2026, 11, 9, 14, 0));
      expect(plan.single.title, 'Hora de estudar programação.');
      expect(plan.single.id, startNotificationId(1));
      expect(isRoutineNotificationId(plan.single.id), isTrue);
    });

    test('sem aviso para o que já passou, começou ou foi encerrado', () {
      final plan = planRoutineNotifications(
        occurrences: [
          occ(1, start: 9 * 60),
          occ(2, status: OccurrenceStatus.inProgress),
          occ(3, status: OccurrenceStatus.paused),
          occ(4, status: OccurrenceStatus.done),
          occ(5, status: OccurrenceStatus.notDone),
          occ(6, kind: ActivityKind.rest),
        ],
        now: now,
      );
      expect(plan, isEmpty);
    });

    test('atraso não gera segunda notificação', () {
      // Passou da tolerância: a ocorrência continua pendente, mas o
      // horário de início já ficou para trás, então nada é agendado.
      final later = DateTime(2026, 11, 9, 14, 30);
      expect(
        planRoutineNotifications(occurrences: [occ(1)], now: later),
        isEmpty,
      );
    });

    test('reagendar muda o horário do aviso, sem duplicar', () {
      final before = planRoutineNotifications(occurrences: [occ(1)], now: now);
      final after = planRoutineNotifications(
        occurrences: [occ(1, start: 16 * 60)],
        now: now,
      );
      expect(after, hasLength(1));
      expect(after.single.id, before.single.id);
      expect(after.single.when, DateTime(2026, 11, 9, 16, 0));
      expect(after.single.payload, isNot(before.single.payload));
      expect(occurrenceIdFromPayload(after.single.payload), 1);
    });

    test('continuação agendada avisa só no seu horário', () {
      final plan = planRoutineNotifications(
        occurrences: [
          occ(
            7,
            status: OccurrenceStatus.awaitingResume,
            continuationDay: monday + 1,
            continuationStart: 10 * 60,
          ),
          // Na Lista de Retomadas (sem horário): nenhum aviso.
          occ(8, status: OccurrenceStatus.awaitingResume),
        ],
        now: now,
      );
      expect(plan, hasLength(1));
      expect(plan.single.id, continuationNotificationId(7));
      expect(plan.single.when, DateTime(2026, 11, 10, 10, 0));
    });

    test('só agenda dentro do horizonte', () {
      final plan = planRoutineNotifications(
        occurrences: [occ(1, dayOffset: 5), occ(2, dayOffset: 40)],
        now: now,
      );
      expect(plan.map((p) => p.occurrenceId), [1]);
    });

    test('payload desconhecido é ignorado', () {
      expect(occurrenceIdFromPayload(null), isNull);
      expect(occurrenceIdFromPayload('outro|3'), isNull);
    });
  });

  group('indicadores', () {
    test('distingue concluída, parcial, não realizada e em aberto', () {
      final s = summarizeRoutine([
        (
          status: OccurrenceStatus.done,
          kind: ActivityKind.flexible,
          timerSeconds: 2400,
        ),
        (
          status: OccurrenceStatus.partial,
          kind: ActivityKind.flexible,
          timerSeconds: 600,
        ),
        (
          status: OccurrenceStatus.notDone,
          kind: ActivityKind.fixed,
          timerSeconds: 0,
        ),
        (
          status: OccurrenceStatus.pending,
          kind: ActivityKind.fixed,
          timerSeconds: 0,
        ),
        (
          status: OccurrenceStatus.awaitingResume,
          kind: ActivityKind.flexible,
          timerSeconds: 300,
        ),
        // Descanso não é atividade a cumprir: fica fora da conta.
        (
          status: OccurrenceStatus.pending,
          kind: ActivityKind.rest,
          timerSeconds: 0,
        ),
      ]);
      expect(s.planned, 5);
      expect(s.done, 1);
      expect(s.partial, 1);
      expect(s.notDone, 1);
      expect(s.open, 2);
      expect(s.timerSeconds, 3300);
      expect(s.completionRate, closeTo(0.2, 1e-9));
    });

    test('período vazio não divide por zero', () {
      expect(summarizeRoutine(const []).completionRate, 0);
    });
  });
}
