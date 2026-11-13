import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:aplicativo_all/core/settings/settings_repository.dart';
import 'package:aplicativo_all/core/utils/dates.dart';
import 'package:aplicativo_all/features/routine/data/routine_repository.dart';
import 'package:aplicativo_all/features/routine/domain/routine_logic.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atividades que começam num dia e terminam no seguinte (ex.: 23h às 3h).
void main() {
  // Segunda-feira, 09/11/2026.
  final monday = epochDay(DateTime(2026, 11, 9));
  const start = 23 * 60;
  final end = normalizeEnd(start, 3 * 60);

  group('regras', () {
    test('término antes do início vai para o dia seguinte', () {
      expect(end, 27 * 60);
      expect(crossesMidnight(end), isTrue);
      expect(end - start, 4 * 60);
      expect(normalizeEnd(14 * 60, 15 * 60), 15 * 60);
      expect(crossesMidnight(15 * 60), isFalse);
    });

    test('duração planejada de 4 horas', () {
      expect(plannedSeconds(start, end), 4 * 3600);
    });

    test('exibição indica o dia seguinte', () {
      expect(formatSpan(start, end), '23:00–03:00 (dia seguinte)');
      expect(formatSpan(14 * 60, 15 * 60), '14:00–15:00');
      expect(formatMinute(end), '03:00');
    });

    test('validação aceita a virada e recusa 24h ou mais', () {
      expect(validateSpan(start, end), isNull);
      expect(validateSpan(600, 600), isNotNull);
      expect(validateSpan(600, 600 + minutesPerDay), isNotNull);
      expect(
        validateActivity(
          name: 'Estudar',
          startMinute: start,
          endMinute: end,
          weekdays: 1,
          singleDay: null,
        ),
        isNull,
      );
    });

    test('conflito é detectado entre os dois dias', () {
      final night = TimeBlock(
        id: 1,
        name: 'Plantão',
        kind: ActivityKind.fixed,
        day: monday,
        start: start,
        end: end,
      );
      // Terça às 2h: dentro do plantão que começou segunda às 23h.
      expect(
        findConflicts(
          day: monday + 1,
          start: 2 * 60,
          end: 2 * 60 + 30,
          blocks: [night],
        ),
        hasLength(1),
      );
      // Terça às 3h: já terminou.
      expect(
        findConflicts(
          day: monday + 1,
          start: 3 * 60,
          end: 4 * 60,
          blocks: [night],
        ),
        isEmpty,
      );
      // Segunda às 22h30–23h30: conflita no próprio dia.
      expect(
        findConflicts(
          day: monday,
          start: 22 * 60 + 30,
          end: 23 * 60 + 30,
          blocks: [night],
        ),
        hasLength(1),
      );
    });

    test('planejamento de domingo à noite conflita com segunda cedo', () {
      expect(
        plansOverlap(
          startA: 23 * 60,
          endA: 26 * 60,
          weekdaysA: maskOf([7]),
          singleDayA: null,
          startB: 60,
          endB: 120,
          weekdaysB: maskOf([1]),
          singleDayB: null,
        ),
        isTrue,
      );
      expect(
        plansOverlap(
          startA: 23 * 60,
          endA: 26 * 60,
          weekdaysA: maskOf([7]),
          singleDayA: null,
          startB: 60,
          endB: 120,
          weekdaysB: maskOf([2]),
          singleDayB: null,
        ),
        isFalse,
      );
    });

    test('notificação continua no horário de início', () {
      final plan = planRoutineNotifications(
        occurrences: [
          NotifiableOccurrence(
            id: 1,
            name: 'Estudar programação',
            kind: ActivityKind.flexible,
            status: OccurrenceStatus.pending,
            scheduledDay: monday,
            scheduledStart: start,
          ),
        ],
        now: DateTime(2026, 11, 9, 12),
      );
      expect(plan.single.when, DateTime(2026, 11, 9, 23));
    });
  });

  group('repositório', () {
    late AppDatabase db;
    late RoutineRepository repo;
    final t0 = DateTime(2026, 11, 9, 8);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = RoutineRepository(db, SettingsRepository(db));
    });
    tearDown(() => db.close());

    Future<void> create() => repo.saveActivity(
      name: 'Estudar programação',
      kind: ActivityKind.flexible,
      startMinute: start,
      endMinute: end,
      weekdays: maskOf([1]),
      timerEnabled: true,
      now: t0,
    );

    test('ocorrência guarda o término do dia seguinte', () async {
      await create();
      final occ = (await db.select(db.routineOccurrences).get()).firstWhere(
        (o) => o.originalDay == monday,
      );
      expect(occ.scheduledStart, start);
      expect(occ.scheduledEnd, end);
      expect(
        dateTimeAt(occ.scheduledDay, occ.scheduledEnd),
        DateTime(2026, 11, 10, 3),
      );
    });

    test('aparece na terça como continuação, sem contar duas vezes', () async {
      await create();
      final tuesday = buildDayEntries(
        await repo.loadDay(monday + 1),
        monday + 1,
      );
      final spill = tuesday.single;
      expect(spill.kind, DayEntryKind.fromPreviousDay);
      expect(spill.end, 3 * 60);
      // Na terça não há ocorrência própria: o resumo do dia é vazio.
      final normals = tuesday.where((e) => e.kind == DayEntryKind.normal);
      expect(normals, isEmpty);
      final monday0 = buildDayEntries(await repo.loadDay(monday), monday);
      expect(monday0.single.kind, DayEntryKind.normal);
    });

    test('recorrência não duplica e cada semana tem uma ocorrência', () async {
      await create();
      await repo.ensureRange(monday, monday + 13);
      await repo.ensureRange(monday, monday + 13);
      final occs = await db.select(db.routineOccurrences).get();
      final days =
          occs.map((o) => o.originalDay).where((d) => d <= monday + 13).toList()
            ..sort();
      expect(days, [monday, monday + 7]);
    });

    test('conflito de terça de madrugada com a atividade de segunda', () async {
      await create();
      final blocks = await repo.blocksAround(monday + 1);
      expect(
        findConflicts(day: monday + 1, start: 120, end: 150, blocks: blocks),
        hasLength(1),
      );
    });

    test(
      'sessão que passa da meia-noite fica na ocorrência original',
      () async {
        await create();
        final id = (await db.select(db.routineOccurrences).get())
            .firstWhere((o) => o.originalDay == monday)
            .id;
        await repo.start(id, DateTime(2026, 11, 9, 23, 10));
        await repo.conclude(id, DateTime(2026, 11, 10, 2, 40));
        final v = (await repo.loadOccurrence(id))!;
        expect(v.occ.originalDay, monday);
        expect(v.sessions, hasLength(1));
        expect(v.doneSeconds(DateTime(2026, 11, 11)), (3 * 60 + 30) * 60);
        expect(v.occ.status, OccurrenceStatus.done);
      },
    );

    test('reagendar para atravessar a meia-noite é aceito', () async {
      await repo.saveActivity(
        name: 'Ler',
        kind: ActivityKind.flexible,
        startMinute: 600,
        endMinute: 660,
        weekdays: maskOf([1]),
        timerEnabled: false,
        now: t0,
      );
      final id = (await db.select(db.routineOccurrences).get()).first.id;
      await repo.reschedule(id, day: monday, start: 22 * 60, end: 25 * 60);
      final occ = (await repo.loadOccurrence(id))!.occ;
      expect(occ.scheduledEnd, 25 * 60);
      await expectLater(
        repo.reschedule(id, day: monday, start: 600, end: 600 + minutesPerDay),
        throwsA(isA<RoutineStateError>()),
      );
    });
  });
}
