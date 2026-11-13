import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:aplicativo_all/core/settings/settings_repository.dart';
import 'package:aplicativo_all/core/utils/dates.dart';
import 'package:aplicativo_all/features/routine/data/routine_repository.dart';
import 'package:aplicativo_all/features/routine/domain/routine_logic.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late RoutineRepository repo;

  // Segunda-feira, 09/11/2026, 08:00.
  final t0 = DateTime(2026, 11, 9, 8, 0);
  final monday = epochDay(t0);
  final monWedFri = maskOf([1, 3, 5]);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RoutineRepository(db, SettingsRepository(db));
  });

  tearDown(() => db.close());

  Future<int> createStudy({bool timer = true}) => repo.saveActivity(
    name: 'Estudar programação',
    kind: ActivityKind.flexible,
    startMinute: 14 * 60,
    endMinute: 15 * 60,
    weekdays: monWedFri,
    timerEnabled: timer,
    now: t0,
  );

  Future<RoutineOccurrence> occOn(int day, {int? activityId}) async {
    final list = await (db.select(
      db.routineOccurrences,
    )..where((o) => o.originalDay.equals(day))).get();
    return activityId == null
        ? list.single
        : list.singleWhere((o) => o.activityId == activityId);
  }

  Future<OccurrenceView> view(int id) async => (await repo.loadOccurrence(id))!;

  group('recorrência', () {
    test('gera uma ocorrência por dia selecionado, sem duplicar', () async {
      await createStudy();
      await repo.ensureRange(monday, monday + 13);
      await repo.ensureRange(monday, monday + 13);
      final occs = await db.select(db.routineOccurrences).get();
      final days = occs.map((o) => o.originalDay - monday).toList()..sort();
      // Segunda, quarta e sexta de duas semanas... e do horizonte gerado
      // ao salvar. Confere só as duas primeiras semanas.
      expect(days.where((d) => d < 14), [0, 2, 4, 7, 9, 11]);
      expect(days.toSet().length, days.length);
    });

    test('a ocorrência copia nome e horário do planejamento', () async {
      await createStudy();
      final occ = await occOn(monday);
      expect(occ.name, 'Estudar programação');
      expect(occ.plannedStart, 14 * 60);
      expect(occ.scheduledEnd, 15 * 60);
      expect(occ.status, OccurrenceStatus.pending);
      expect(occ.rescheduled, isFalse);
    });

    test('atividade criada depois do horário começa no dia seguinte', () async {
      await repo.saveActivity(
        name: 'Caminhar',
        kind: ActivityKind.flexible,
        startMinute: 6 * 60,
        endMinute: 7 * 60,
        weekdays: allWeekdaysMask,
        timerEnabled: false,
        now: t0,
      );
      final today = await (db.select(
        db.routineOccurrences,
      )..where((o) => o.originalDay.equals(monday))).get();
      expect(today, isEmpty);
      expect((await occOn(monday + 1)).name, 'Caminhar');
    });

    test('compromisso de data única gera só aquela ocorrência', () async {
      await repo.saveActivity(
        name: 'Consulta',
        kind: ActivityKind.fixed,
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        weekdays: 0,
        singleDay: monday + 3,
        timerEnabled: false,
        now: t0,
      );
      final occs = await db.select(db.routineOccurrences).get();
      expect(occs.single.originalDay, monday + 3);
      expect(occs.single.kind, ActivityKind.fixed);
    });

    test('dias passados com o app fechado são gerados ao abrir', () async {
      await createStudy();
      await repo.ensureUpToDate(monday);
      // Abre o app de novo só 30 dias depois.
      await repo.ensureUpToDate(monday + 30);
      final occ = await occOn(monday + 16); // quarta-feira, 25/11
      expect(occ.status, OccurrenceStatus.pending);
      final far = await occOn(monday + 30 + 21 - 2); // dentro do horizonte
      expect(far.name, 'Estudar programação');
    });
  });

  group('ocorrência é independente do planejamento', () {
    test('reagendar a de segunda não muda a de quarta nem o modelo', () async {
      final activityId = await createStudy();
      final mon = await occOn(monday);
      await repo.reschedule(
        mon.id,
        day: monday + 1,
        start: 16 * 60,
        end: 17 * 60,
      );

      final moved = await occOn(monday);
      expect(moved.scheduledDay, monday + 1);
      expect(moved.scheduledStart, 16 * 60);
      expect(moved.rescheduled, isTrue);
      // O planejamento original fica guardado.
      expect(moved.plannedStart, 14 * 60);
      expect(moved.originalDay, monday);

      final wed = await occOn(monday + 2);
      expect(wed.scheduledStart, 14 * 60);
      expect(wed.rescheduled, isFalse);

      final activity = await (db.select(
        db.routineActivities,
      )..where((a) => a.id.equals(activityId))).getSingle();
      expect(activity.startMinute, 14 * 60);
    });

    test('reagendar não cria ocorrência duplicada', () async {
      await createStudy();
      final before = (await db.select(db.routineOccurrences).get()).length;
      final mon = await occOn(monday);
      await repo.reschedule(mon.id, day: monday + 1, start: 600, end: 660);
      await repo.ensureRange(monday, monday + 13);
      final after = (await db.select(db.routineOccurrences).get()).length;
      expect(after, before);
      // Aparece no dia novo e, como "saiu daqui", no dia original.
      final newDay = buildDayEntries(
        await repo.loadDay(monday + 1),
        monday + 1,
      );
      expect(newDay.single.kind, DayEntryKind.normal);
      final oldDay = buildDayEntries(await repo.loadDay(monday), monday);
      expect(oldDay.single.kind, DayEntryKind.movedAway);
    });

    test('concluir uma ocorrência não conclui as outras', () async {
      await createStudy();
      final mon = await occOn(monday);
      await repo.conclude(mon.id, t0);
      expect((await occOn(monday)).status, OccurrenceStatus.done);
      expect((await occOn(monday + 2)).status, OccurrenceStatus.pending);
    });

    test('não realizada fica no histórico e as próximas seguem', () async {
      await createStudy();
      final mon = await occOn(monday);
      await repo.markNotDone(mon.id, t0.add(const Duration(hours: 9)));
      final closed = await occOn(monday);
      expect(closed.status, OccurrenceStatus.notDone);
      expect(closed.closedAt, isNotNull);
      expect((await occOn(monday + 2)).status, OccurrenceStatus.pending);
    });

    test('editar o planejamento só muda o futuro intocado', () async {
      final activityId = await createStudy();
      final mon = await occOn(monday);
      final wed = await occOn(monday + 2);
      await repo.conclude(mon.id, t0);
      await repo.reschedule(wed.id, day: monday + 2, start: 600, end: 660);

      await repo.saveActivity(
        id: activityId,
        name: 'Estudar Flutter',
        kind: ActivityKind.flexible,
        startMinute: 18 * 60,
        endMinute: 19 * 60,
        weekdays: monWedFri,
        timerEnabled: true,
        now: t0,
      );

      // Já concluída: mantém o nome e o horário de quando aconteceu.
      final done = await occOn(monday);
      expect(done.name, 'Estudar programação');
      expect(done.plannedStart, 14 * 60);
      // Reagendada à mão: a decisão do usuário é preservada.
      expect((await occOn(monday + 2)).scheduledStart, 600);
      // Intocada no futuro: segue o novo planejamento.
      final fri = await occOn(monday + 4);
      expect(fri.name, 'Estudar Flutter');
      expect(fri.plannedStart, 18 * 60);
    });

    test('remover do planejamento preserva o histórico', () async {
      final activityId = await createStudy();
      final mon = await occOn(monday);
      await repo.conclude(mon.id, t0);
      await repo.archiveActivity(activityId, monday);

      final occs = await db.select(db.routineOccurrences).get();
      expect(occs.single.id, mon.id);
      expect(await repo.activeActivities(), isEmpty);
      // Não volta a gerar ocorrências.
      await repo.ensureRange(monday, monday + 20);
      expect(await db.select(db.routineOccurrences).get(), hasLength(1));
    });

    test('atividade sem histórico é apagada de vez ao remover', () async {
      final activityId = await createStudy();
      await repo.archiveActivity(activityId, monday);
      expect(await db.select(db.routineActivities).get(), isEmpty);
      expect(await db.select(db.routineOccurrences).get(), isEmpty);
    });
  });

  group('cronômetro e sessões', () {
    test('pausar para a contagem e continuar segue do acumulado', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      final start = DateTime(2026, 11, 9, 14, 0);

      await repo.start(id, start);
      expect(
        (await view(id)).doneSeconds(start.add(const Duration(minutes: 10))),
        600,
      );

      await repo.pause(id, start.add(const Duration(minutes: 10)));
      // Uma hora pausada não conta.
      expect(
        (await view(id)).doneSeconds(start.add(const Duration(minutes: 70))),
        600,
      );
      expect((await view(id)).occ.status, OccurrenceStatus.paused);

      await repo.resume(id, start.add(const Duration(minutes: 70)));
      expect(
        (await view(id)).doneSeconds(start.add(const Duration(minutes: 85))),
        1500,
      );
      // Pausar e continuar não cria outra sessão.
      expect((await view(id)).sessions, hasLength(1));
    });

    test('concluir com 40 de 60 minutos é válido', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      final start = DateTime(2026, 11, 9, 14, 0);
      await repo.start(id, start);
      final end = start.add(const Duration(minutes: 40));
      await repo.conclude(id, end);

      final v = await view(id);
      expect(v.occ.status, OccurrenceStatus.done);
      expect(v.plannedSecs, 3600);
      expect(v.doneSeconds(end.add(const Duration(hours: 5))), 2400);
      expect(v.sessions.single.endedAt, end);
    });

    test('começar depois do horário registra a execução real', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      final late = DateTime(2026, 11, 9, 16, 30);
      await repo.start(id, late);
      final v = await view(id);
      expect(v.sessions.single.startedAt, late);
      // O planejado continua guardado, separado do que aconteceu.
      expect(v.occ.plannedStart, 14 * 60);
    });

    test('atividade sem cronômetro conclui sem iniciar', () async {
      await createStudy(timer: false);
      final id = (await occOn(monday)).id;
      await repo.conclude(id, t0);
      final v = await view(id);
      expect(v.occ.status, OccurrenceStatus.done);
      expect(v.sessions, isEmpty);
    });

    test('três sessões formam uma única ocorrência', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      var t = DateTime(2026, 11, 9, 14, 0);

      await repo.start(id, t);
      t = t.add(const Duration(minutes: 25));
      await repo.addToResumeList(id, t);

      t = DateTime(2026, 11, 10, 9, 0);
      await repo.start(id, t);
      t = t.add(const Duration(minutes: 20));
      await repo.addToResumeList(id, t);

      t = DateTime(2026, 11, 11, 20, 0);
      await repo.start(id, t);
      t = t.add(const Duration(minutes: 15));
      await repo.conclude(id, t);

      final v = await view(id);
      expect(v.sessions, hasLength(3));
      expect(v.doneSeconds(t), 60 * 60);
      expect(v.occ.status, OccurrenceStatus.done);
      // Continua sendo uma ocorrência só naquele dia.
      final sameDay = await (db.select(
        db.routineOccurrences,
      )..where((o) => o.originalDay.equals(monday))).get();
      expect(sameDay, hasLength(1));
    });

    test('tempo em andamento sobrevive a reabrir o banco', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      final start = DateTime(2026, 11, 9, 14, 0);
      await repo.start(id, start);
      // Outro repositório sobre o mesmo banco simula o app reaberto: a
      // contagem vem do horário gravado, não da memória.
      final reopened = RoutineRepository(db, SettingsRepository(db));
      final v = (await reopened.loadOccurrence(id))!;
      expect(v.occ.status, OccurrenceStatus.inProgress);
      expect(v.doneSeconds(start.add(const Duration(minutes: 30))), 1800);
    });
  });

  group('mudanças de estado inválidas', () {
    test('não dá para pausar o que não começou', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      await expectLater(repo.pause(id, t0), throwsA(isA<RoutineStateError>()));
      expect((await occOn(monday)).status, OccurrenceStatus.pending);
    });

    test('não dá para reagendar algo em andamento', () async {
      await createStudy();
      final id = (await occOn(monday)).id;
      await repo.start(id, t0);
      await expectLater(
        repo.reschedule(id, day: monday + 1, start: 60, end: 120),
        throwsA(isA<RoutineStateError>()),
      );
    });

    test('encerramento desfeito volta a um estado utilizável', () async {
      await createStudy();
      final mon = (await occOn(monday)).id;
      await repo.markNotDone(mon, t0);
      await repo.reopen(mon);
      expect((await occOn(monday)).status, OccurrenceStatus.pending);

      final wed = (await occOn(monday + 2)).id;
      await repo.start(wed, t0);
      await repo.conclude(wed, t0.add(const Duration(minutes: 5)));
      await repo.reopen(wed);
      final v = await view(wed);
      expect(v.occ.status, OccurrenceStatus.paused);
      expect(v.doneSeconds(t0.add(const Duration(hours: 2))), 300);
    });
  });

  group('Lista de Retomadas', () {
    Future<int> interrupted(String name, DateTime when) async {
      final activityId = await repo.saveActivity(
        name: name,
        kind: ActivityKind.flexible,
        startMinute: 14 * 60,
        endMinute: 15 * 60,
        weekdays: allWeekdaysMask,
        timerEnabled: true,
        now: t0,
      );
      final occ = await occOn(monday, activityId: activityId);
      await repo.start(occ.id, when);
      await repo.addToResumeList(occ.id, when.add(const Duration(minutes: 10)));
      return occ.id;
    }

    test('mais antigas primeiro, pela data de entrada', () async {
      final math = await interrupted('Matemática', DateTime(2026, 11, 11, 9));
      final code = await interrupted('Programação', DateTime(2026, 11, 9, 9));
      final book = await interrupted('Ler um livro', DateTime(2026, 11, 10, 9));
      final list = await repo.loadResumeList();
      expect(list.map((v) => v.id), [code, book, math]);
    });

    test('guarda o progresso e o que falta', () async {
      final id = await interrupted('Programação', DateTime(2026, 11, 9, 14));
      final v = (await repo.loadResumeList()).single;
      expect(v.id, id);
      expect(v.inResumeList, isTrue);
      expect(v.occ.status, OccurrenceStatus.awaitingResume);
      final now = DateTime(2026, 11, 12);
      expect(v.doneSeconds(now), 600);
      expect(remainingSeconds(v.plannedSecs, v.doneSeconds(now)), 3000);
    });

    test('a mesma ocorrência nunca entra duas vezes', () async {
      final id = await interrupted('Programação', DateTime(2026, 11, 9, 14));
      await repo.addToResumeList(id, DateTime(2026, 11, 9, 20));
      await repo.addToResumeList(id, DateTime(2026, 11, 10, 20));
      expect(await repo.loadResumeList(), hasLength(1));
      expect(await db.select(db.routineResumes).get(), hasLength(1));
    });

    test('retomar e interromper de novo mantém a posição original', () async {
      final first = await interrupted('Programação', DateTime(2026, 11, 9, 9));
      final second = await interrupted('Leitura', DateTime(2026, 11, 10, 9));

      // Dias depois, retoma a primeira e interrompe outra vez.
      await repo.start(first, DateTime(2026, 11, 12, 9));
      expect((await repo.loadResumeList()).map((v) => v.id), [second]);
      await repo.addToResumeList(first, DateTime(2026, 11, 12, 9, 15));

      final list = await repo.loadResumeList();
      expect(list.map((v) => v.id), [first, second]);
      expect(list.first.resume!.listEnteredAt, DateTime(2026, 11, 9, 9, 10));
      // E o tempo das duas sessões foi somado.
      expect(list.first.doneSeconds(DateTime(2026, 11, 13)), 25 * 60);
    });

    test('consultar a lista não muda a ordem', () async {
      final a = await interrupted('A', DateTime(2026, 11, 9, 9));
      final b = await interrupted('B', DateTime(2026, 11, 10, 9));
      await repo.loadOccurrence(b);
      await repo.loadResumeList();
      expect((await repo.loadResumeList()).map((v) => v.id), [a, b]);
    });

    test('concluir tira da lista, mas mantém no histórico', () async {
      final id = await interrupted('Programação', DateTime(2026, 11, 9, 14));
      await repo.conclude(id, DateTime(2026, 11, 12, 10));
      expect(await repo.loadResumeList(), isEmpty);
      final v = await view(id);
      expect(v.occ.status, OccurrenceStatus.done);
      expect(v.sessions, hasLength(1));
      expect(v.resume!.resolvedAt, DateTime(2026, 11, 12, 10));
    });

    test('encerrar como parcial também tira da lista', () async {
      final id = await interrupted('Programação', DateTime(2026, 11, 9, 14));
      await repo.closePartial(id, DateTime(2026, 11, 12, 10));
      expect(await repo.loadResumeList(), isEmpty);
      expect((await view(id)).occ.status, OccurrenceStatus.partial);
    });

    test('continuação agendada sai da lista e entra no dia marcado', () async {
      final id = await interrupted('Programação', DateTime(2026, 11, 9, 14));
      await repo.scheduleContinuation(
        id,
        day: monday + 2,
        start: 10 * 60,
        end: 10 * 60 + 50,
        now: DateTime(2026, 11, 9, 15),
      );
      expect(await repo.loadResumeList(), isEmpty);
      final entries = buildDayEntries(
        await repo.loadDay(monday + 2),
        monday + 2,
      );
      final continuation = entries.singleWhere(
        (e) => e.kind == DayEntryKind.continuation,
      );
      expect(continuation.view.id, id);
      expect(continuation.start, 10 * 60);
      // A continuação ocupa o horário na verificação de conflitos.
      final blocks = await repo.blocksAround(monday + 2);
      expect(
        findConflicts(
          day: monday + 2,
          start: 10 * 60 + 30,
          end: 11 * 60,
          blocks: blocks,
        ).map((b) => b.id),
        contains(id),
      );
    });

    test('nada sai da lista sozinho com o passar do tempo', () async {
      await interrupted('Programação', DateTime(2026, 11, 9, 14));
      await repo.ensureUpToDate(monday + 60);
      expect(await repo.loadResumeList(), hasLength(1));
    });
  });

  group('reorganizar', () {
    test('aplica os novos horários só no dia escolhido', () async {
      await createStudy();
      final mon = await occOn(monday);
      await repo.applyReorganization(monday, {
        mon.id: (start: 16 * 60, end: 17 * 60),
      });
      final moved = await occOn(monday);
      expect(moved.scheduledStart, 16 * 60);
      expect(moved.scheduledDay, monday);
      expect(moved.rescheduled, isTrue);
      expect((await occOn(monday + 2)).scheduledStart, 14 * 60);
    });

    test('horário inválido desfaz tudo', () async {
      await createStudy();
      final mon = await occOn(monday);
      final wed = await occOn(monday + 2);
      await expectLater(
        repo.applyReorganization(monday, {
          mon.id: (start: 16 * 60, end: 17 * 60),
          wed.id: (start: 600, end: 600),
        }),
        throwsA(isA<RoutineStateError>()),
      );
      expect((await occOn(monday)).scheduledStart, 14 * 60);
    });
  });

  test('tolerância é configurável e fica gravada', () async {
    expect(await repo.tolerance(), defaultToleranceMinutes);
    await repo.setTolerance(30);
    expect(await RoutineRepository(db, SettingsRepository(db)).tolerance(), 30);
  });

  test(
    'ocorrências pendentes e continuações entram no plano de avisos',
    () async {
      await createStudy();
      final mon = (await occOn(monday)).id;
      final wed = (await occOn(monday + 2)).id;
      await repo.start(wed, t0);
      await repo.scheduleContinuation(
        wed,
        day: monday + 3,
        start: 9 * 60,
        end: 10 * 60,
        now: t0.add(const Duration(minutes: 5)),
      );
      final plan = planRoutineNotifications(
        occurrences: await repo.loadNotifiable(monday),
        now: t0.add(const Duration(minutes: 5)),
      );
      final ids = plan.map((p) => p.id).toSet();
      expect(ids, contains(startNotificationId(mon)));
      expect(ids, contains(continuationNotificationId(wed)));
      expect(ids, isNot(contains(startNotificationId(wed))));
      // Uma notificação por ocorrência: nenhum id repetido.
      expect(ids.length, plan.length);
    },
  );

  test('Value do drift não é confundido com o matcher', () {
    // Garante que o import "hide" acima segue necessário.
    expect(const Value<int?>(null).value, isNull);
  });
}
