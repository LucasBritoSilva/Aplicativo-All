/// Regras da rotina híbrida, sem banco e sem tela: tudo aqui é testável.
library;

import '../../../core/utils/dates.dart';
import '../../../core/utils/text.dart';
import '../data/routine_tables.dart';

/// Tolerância de atraso usada até o usuário escolher outra.
const defaultToleranceMinutes = 15;

/// Quantos dias à frente as ocorrências e as notificações ficam prontas.
const routineHorizonDays = 21;

// ---------------------------------------------------------------------
// Dias da semana (máscara de bits: bit 0 = segunda ... bit 6 = domingo)
// ---------------------------------------------------------------------

const allWeekdaysMask = 127;
const workdaysMask = 31;
const weekendMask = 96;

const _weekdayNames = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

bool maskHasWeekday(int mask, int weekday) => mask & (1 << (weekday - 1)) != 0;

int maskOf(Iterable<int> weekdays) =>
    weekdays.fold(0, (mask, day) => mask | (1 << (day - 1)));

List<int> weekdaysOf(int mask) => [
  for (var day = 1; day <= 7; day++)
    if (maskHasWeekday(mask, day)) day,
];

/// "Todos os dias", "Segunda a sexta" ou "seg, qua, sex".
String describeWeekdays(int mask) {
  if (mask == allWeekdaysMask) return 'Todos os dias';
  if (mask == workdaysMask) return 'Segunda a sexta';
  if (mask == weekendMask) return 'Fins de semana';
  if (mask == 0) return 'Sem repetição';
  return weekdaysOf(mask).map((d) => _weekdayNames[d - 1]).join(', ');
}

/// Se uma atividade recorrente gera ocorrência no dia [day].
///
/// [singleDay] preenchido significa compromisso de data única (sem
/// repetição). [archivedDay] é o primeiro dia sem ocorrências.
bool activityOccursOn({
  required int weekdays,
  required int? singleDay,
  required int startDay,
  required int? archivedDay,
  required int day,
}) {
  if (archivedDay != null && day >= archivedDay) return false;
  if (singleDay != null) return singleDay == day;
  if (day < startDay) return false;
  return maskHasWeekday(weekdays, weekdayOfEpochDay(day));
}

/// Confere os dados de uma atividade. Devolve a mensagem de erro, ou nulo.
String? validateActivity({
  required String name,
  required int startMinute,
  required int endMinute,
  required int weekdays,
  required int? singleDay,
}) {
  if (name.trim().isEmpty) return 'Dê um nome para a atividade.';
  if (endMinute <= startMinute) {
    return 'O horário de término precisa ser depois do início.';
  }
  if (singleDay == null && weekdays == 0) {
    return 'Escolha pelo menos um dia da semana.';
  }
  return null;
}

// ---------------------------------------------------------------------
// Estados
// ---------------------------------------------------------------------

/// Estado mostrado ao usuário (os nove estados da especificação).
enum DisplayState {
  pending('Pendente'),
  inProgress('Em andamento'),
  paused('Pausada'),
  late('Atrasada'),
  awaitingResume('Aguardando retomada'),
  done('Concluída'),
  partial('Parcial'),
  notDone('Não realizada'),
  rescheduled('Reagendada');

  const DisplayState(this.label);
  final String label;

  /// Ocorrência encerrada (só aparece no histórico).
  bool get isClosed =>
      this == DisplayState.done ||
      this == DisplayState.partial ||
      this == DisplayState.notDone;
}

/// Calcula o estado mostrado a partir do estado gravado e da hora atual.
///
/// "Atrasada" vale para a ocorrência que passou da tolerância sem ser
/// iniciada. É só uma indicação: nada é encerrado nem reagendado sozinho.
/// Períodos de descanso nunca ficam atrasados.
DisplayState displayState({
  required OccurrenceStatus status,
  required ActivityKind kind,
  required bool rescheduled,
  required int scheduledDay,
  required int scheduledStart,
  required int toleranceMinutes,
  required DateTime now,
}) {
  switch (status) {
    case OccurrenceStatus.inProgress:
      return DisplayState.inProgress;
    case OccurrenceStatus.paused:
      return DisplayState.paused;
    case OccurrenceStatus.awaitingResume:
      return DisplayState.awaitingResume;
    case OccurrenceStatus.done:
      return DisplayState.done;
    case OccurrenceStatus.partial:
      return DisplayState.partial;
    case OccurrenceStatus.notDone:
      return DisplayState.notDone;
    case OccurrenceStatus.pending:
      if (kind != ActivityKind.rest) {
        final limit = dateTimeAt(
          scheduledDay,
          scheduledStart,
        ).add(Duration(minutes: toleranceMinutes));
        if (now.isAfter(limit)) return DisplayState.late;
      }
      return rescheduled ? DisplayState.rescheduled : DisplayState.pending;
  }
}

/// O que o usuário pode fazer com uma ocorrência.
enum OccurrenceAction {
  start,
  pause,
  resume,
  conclude,
  closePartial,
  markNotDone,
  reschedule,
  continueLater,
  reopen,
}

/// Ações permitidas em cada estado gravado.
///
/// Toda mudança de estado passa por aqui, então o banco nunca fica em um
/// estado impossível (por exemplo, pausar algo que não começou).
Set<OccurrenceAction> allowedActions(
  OccurrenceStatus status, {
  ActivityKind kind = ActivityKind.flexible,
}) {
  if (kind == ActivityKind.rest) {
    // Descanso é só um bloco de tempo: pode ser movido, não "cumprido".
    return status == OccurrenceStatus.pending
        ? const {OccurrenceAction.reschedule}
        : const {};
  }
  return switch (status) {
    OccurrenceStatus.pending => const {
      OccurrenceAction.start,
      OccurrenceAction.conclude,
      OccurrenceAction.markNotDone,
      OccurrenceAction.reschedule,
    },
    OccurrenceStatus.inProgress => const {
      OccurrenceAction.pause,
      OccurrenceAction.conclude,
      OccurrenceAction.closePartial,
      OccurrenceAction.continueLater,
    },
    OccurrenceStatus.paused => const {
      OccurrenceAction.resume,
      OccurrenceAction.conclude,
      OccurrenceAction.closePartial,
      OccurrenceAction.continueLater,
    },
    OccurrenceStatus.awaitingResume => const {
      OccurrenceAction.start,
      OccurrenceAction.conclude,
      OccurrenceAction.closePartial,
      OccurrenceAction.continueLater,
    },
    OccurrenceStatus.done ||
    OccurrenceStatus.partial ||
    OccurrenceStatus.notDone => const {OccurrenceAction.reopen},
  };
}

// ---------------------------------------------------------------------
// Tempo planejado e tempo realizado
// ---------------------------------------------------------------------

/// Segundos de uma sessão: o acumulado mais o trecho em andamento.
///
/// Se o relógio do aparelho voltar no tempo, o trecho em andamento conta
/// como zero em vez de ficar negativo.
int sessionSeconds({
  required int accumulatedSeconds,
  required DateTime? runningSince,
  required DateTime now,
}) {
  if (runningSince == null) return accumulatedSeconds;
  final extra = now.difference(runningSince).inSeconds;
  return accumulatedSeconds + (extra > 0 ? extra : 0);
}

int plannedSeconds(int startMinute, int endMinute) =>
    (endMinute - startMinute) * 60;

/// Quanto falta do tempo planejado (nunca negativo).
int remainingSeconds(int planned, int done) =>
    done >= planned ? 0 : planned - done;

// ---------------------------------------------------------------------
// Conflitos de horário
// ---------------------------------------------------------------------

/// Um bloco de tempo ocupado em um dia.
class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.name,
    required this.kind,
    required this.day,
    required this.start,
    required this.end,
  });

  /// Id da ocorrência dona do bloco.
  final int id;
  final String name;
  final ActivityKind kind;
  final int day;
  final int start;
  final int end;
}

/// Blocos que se sobrepõem ao intervalo [start, end) no dia [day].
///
/// Encostar não é conflito (um termina às 15h e outro começa às 15h).
/// [ignoreId] tira da conta a própria ocorrência que está sendo movida.
List<TimeBlock> findConflicts({
  required int day,
  required int start,
  required int end,
  required Iterable<TimeBlock> blocks,
  int? ignoreId,
}) {
  final found = [
    for (final b in blocks)
      if (b.id != ignoreId && b.day == day && b.start < end && start < b.end) b,
  ];
  found.sort((a, b) => a.start.compareTo(b.start));
  return found;
}

/// Frase para avisar um conflito.
String describeConflict(TimeBlock block) {
  final time = '${formatMinute(block.start)}–${formatMinute(block.end)}';
  final kind = block.kind == ActivityKind.fixed ? ' (compromisso fixo)' : '';
  return '${block.name}, $time$kind';
}

// ---------------------------------------------------------------------
// Lista de Retomadas
// ---------------------------------------------------------------------

/// Ordem da Lista de Retomadas: mais antigas primeiro, pela data de
/// entrada na lista. O id desempata, para a ordem ser sempre a mesma.
int compareResumeEntries(
  ({int id, DateTime enteredAt}) a,
  ({int id, DateTime enteredAt}) b,
) {
  final byDate = a.enteredAt.compareTo(b.enteredAt);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

// ---------------------------------------------------------------------
// Notificações
// ---------------------------------------------------------------------

/// Faixa de ids reservada às notificações da rotina. Os lembretes usam o
/// próprio id (números pequenos), então as duas faixas nunca se misturam.
const routineNotificationBase = 1000000000;
const routineNotificationLimit = 2000000000;

bool isRoutineNotificationId(int id) =>
    id >= routineNotificationBase && id < routineNotificationLimit;

int startNotificationId(int occurrenceId) =>
    routineNotificationBase + occurrenceId * 2;

int continuationNotificationId(int occurrenceId) =>
    routineNotificationBase + occurrenceId * 2 + 1;

/// "Hora de estudar programação."
String startNotificationTitle(String name) => 'Hora de ${lowerFirst(name)}.';

String continuationNotificationTitle(String name) =>
    'Hora de continuar: ${lowerFirst(name)}.';

/// Dados de uma ocorrência que interessam ao agendamento.
class NotifiableOccurrence {
  const NotifiableOccurrence({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    required this.scheduledDay,
    required this.scheduledStart,
    this.continuationDay,
    this.continuationStart,
  });

  final int id;
  final String name;
  final ActivityKind kind;
  final OccurrenceStatus status;
  final int scheduledDay;
  final int scheduledStart;
  final int? continuationDay;
  final int? continuationStart;
}

/// Uma notificação que deve estar agendada.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.occurrenceId,
    required this.title,
    required this.when,
  });

  final int id;
  final int occurrenceId;
  final String title;
  final DateTime when;

  /// Identifica a ocorrência e o horário: se o horário mudar, o texto
  /// muda e a notificação antiga é trocada pela nova.
  String get payload => 'rotina|$occurrenceId|${when.millisecondsSinceEpoch}';
}

/// Lê o id da ocorrência de um [PlannedNotification.payload].
int? occurrenceIdFromPayload(String? payload) {
  if (payload == null) return null;
  final parts = payload.split('|');
  if (parts.length < 2 || parts.first != 'rotina') return null;
  return int.tryParse(parts[1]);
}

/// Quais notificações devem existir agora.
///
/// Regra da especificação: uma única notificação, no horário de início de
/// cada atividade programada. Não há aviso antecipado, repetição nem
/// cobrança por atraso. Descanso não notifica. Uma continuação agendada
/// pelo usuário também avisa só no seu horário de início.
List<PlannedNotification> planRoutineNotifications({
  required Iterable<NotifiableOccurrence> occurrences,
  required DateTime now,
  int horizonDays = routineHorizonDays,
}) {
  final limit = now.add(Duration(days: horizonDays));
  final out = <PlannedNotification>[];
  for (final o in occurrences) {
    if (o.kind == ActivityKind.rest) continue;
    if (o.status == OccurrenceStatus.pending) {
      final when = dateTimeAt(o.scheduledDay, o.scheduledStart);
      if (when.isAfter(now) && !when.isAfter(limit)) {
        out.add(
          PlannedNotification(
            id: startNotificationId(o.id),
            occurrenceId: o.id,
            title: startNotificationTitle(o.name),
            when: when,
          ),
        );
      }
    } else if (o.status == OccurrenceStatus.awaitingResume &&
        o.continuationDay != null &&
        o.continuationStart != null) {
      final when = dateTimeAt(o.continuationDay!, o.continuationStart!);
      if (when.isAfter(now) && !when.isAfter(limit)) {
        out.add(
          PlannedNotification(
            id: continuationNotificationId(o.id),
            occurrenceId: o.id,
            title: continuationNotificationTitle(o.name),
            when: when,
          ),
        );
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------
// Indicadores
// ---------------------------------------------------------------------

/// Resumo da execução da rotina em um período.
class RoutineSummary {
  const RoutineSummary({
    required this.planned,
    required this.done,
    required this.partial,
    required this.notDone,
    required this.open,
    required this.timerSeconds,
  });

  /// Atividades planejadas (descanso não entra na conta).
  final int planned;
  final int done;
  final int partial;
  final int notDone;

  /// Ainda sem desfecho: pendentes, em andamento, pausadas ou aguardando
  /// retomada. Não contam como falha.
  final int open;

  /// Tempo total registrado pelos cronômetros.
  final int timerSeconds;

  /// Fração concluída (0 a 1). Parcial não conta como conclusão total.
  double get completionRate => planned == 0 ? 0 : done / planned;
}

RoutineSummary summarizeRoutine(
  Iterable<({OccurrenceStatus status, ActivityKind kind, int timerSeconds})>
  occurrences,
) {
  var planned = 0, done = 0, partial = 0, notDone = 0, open = 0, seconds = 0;
  for (final o in occurrences) {
    if (o.kind == ActivityKind.rest) continue;
    planned++;
    seconds += o.timerSeconds;
    switch (o.status) {
      case OccurrenceStatus.done:
        done++;
      case OccurrenceStatus.partial:
        partial++;
      case OccurrenceStatus.notDone:
        notDone++;
      case OccurrenceStatus.pending ||
          OccurrenceStatus.inProgress ||
          OccurrenceStatus.paused ||
          OccurrenceStatus.awaitingResume:
        open++;
    }
  }
  return RoutineSummary(
    planned: planned,
    done: done,
    partial: partial,
    notDone: notDone,
    open: open,
    timerSeconds: seconds,
  );
}

// ---------------------------------------------------------------------
// Conflitos no planejamento recorrente
// ---------------------------------------------------------------------

/// Se duas atividades planejadas ocupam o mesmo horário em algum dia em
/// comum (mesmo dia da semana, ou a data única de uma cai num dia da
/// outra). Serve para avisar o usuário ao planejar; a decisão é dele.
bool plansOverlap({
  required int startA,
  required int endA,
  required int weekdaysA,
  required int? singleDayA,
  required int startB,
  required int endB,
  required int weekdaysB,
  required int? singleDayB,
}) {
  if (!(startA < endB && startB < endA)) return false;
  if (singleDayA != null && singleDayB != null) return singleDayA == singleDayB;
  if (singleDayA != null) {
    return maskHasWeekday(weekdaysB, weekdayOfEpochDay(singleDayA));
  }
  if (singleDayB != null) {
    return maskHasWeekday(weekdaysA, weekdayOfEpochDay(singleDayB));
  }
  return weekdaysA & weekdaysB != 0;
}
