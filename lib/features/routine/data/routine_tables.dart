import 'package:drift/drift.dart';

/// Tipo de atividade da rotina híbrida.
enum ActivityKind {
  /// Compromisso com horário definido (faculdade, trabalho, consulta).
  fixed('Compromisso fixo'),

  /// Atividade planejada que pode ser adaptada (estudar, ler, treinar).
  flexible('Atividade flexível'),

  /// Descanso, lazer, pausa ou tempo pessoal.
  rest('Descanso / tempo livre');

  const ActivityKind(this.label);
  final String label;
}

/// Estado gravado de uma ocorrência.
///
/// "Atrasada" e "Reagendada" não são gravados: são calculados na hora de
/// mostrar (ver `routine_logic.dart`), para nunca ficarem desatualizados.
enum OccurrenceStatus {
  pending,
  inProgress,
  paused,
  awaitingResume,
  done,
  partial,
  notDone,
}

/// Atividade recorrente: o planejamento feito pelo usuário.
///
/// Os horários são minutos desde a meia-noite e os dias são números
/// inteiros (dias desde 01/01/1970), para não depender do fuso horário.
@DataClassName('RoutineActivity')
class RoutineActivities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get kind => textEnum<ActivityKind>()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();

  /// Dias da semana em bits: bit 0 = segunda ... bit 6 = domingo.
  IntColumn get weekdays => integer().withDefault(const Constant(0))();

  /// Dia único, para compromisso sem repetição. Nulo se for semanal.
  IntColumn get singleDay => integer().nullable()();
  BoolColumn get timerEnabled => boolean().withDefault(const Constant(false))();

  /// Primeiro dia em que a atividade gera ocorrências.
  IntColumn get startDay => integer()();

  /// Dia a partir do qual a atividade deixa de gerar ocorrências.
  IntColumn get archivedDay => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Ocorrência: uma atividade em um dia específico, com estado próprio.
///
/// Guarda uma cópia do nome e do horário planejado, para que editar a
/// atividade recorrente não altere o histórico.
class RoutineOccurrences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId => integer().references(RoutineActivities, #id)();

  /// Dia em que a ocorrência foi planejada originalmente.
  IntColumn get originalDay => integer()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<ActivityKind>()();
  BoolColumn get timerEnabled => boolean()();
  IntColumn get plannedStart => integer()();
  IntColumn get plannedEnd => integer()();

  /// Dia e horário atuais (iguais ao planejado até um reagendamento).
  IntColumn get scheduledDay => integer()();
  IntColumn get scheduledStart => integer()();
  IntColumn get scheduledEnd => integer()();
  BoolColumn get rescheduled => boolean().withDefault(const Constant(false))();
  TextColumn get status =>
      textEnum<OccurrenceStatus>().withDefault(const Constant('pending'))();
  DateTimeColumn get closedAt => dateTime().nullable()();

  /// Uma atividade tem no máximo uma ocorrência por dia planejado:
  /// reagendar altera esta mesma linha, sem duplicar.
  @override
  List<Set<Column>> get uniqueKeys => [
    {activityId, originalDay},
  ];
}

/// Sessão de execução: um período em que a ocorrência foi realizada.
class RoutineSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get occurrenceId => integer().references(
    RoutineOccurrences,
    #id,
    onDelete: KeyAction.cascade,
  )();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// Segundos já contados nesta sessão (sem o trecho em andamento).
  IntColumn get accumulatedSeconds =>
      integer().withDefault(const Constant(0))();

  /// Momento em que a contagem foi (re)iniciada; nulo quando pausada.
  DateTimeColumn get runningSince => dateTime().nullable()();
}

/// Retomada pendente: ocorrência interrompida que aguarda continuação.
class RoutineResumes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `unique`: a mesma ocorrência nunca entra duas vezes.
  IntColumn get occurrenceId => integer().unique().references(
    RoutineOccurrences,
    #id,
    onDelete: KeyAction.cascade,
  )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Quando entrou na Lista de Retomadas pela primeira vez. É a referência
  /// da ordem da lista e não muda se a atividade for interrompida de novo.
  DateTimeColumn get listEnteredAt => dateTime().nullable()();

  /// Continuação agendada manualmente (nulo = está na Lista de Retomadas).
  IntColumn get scheduledDay => integer().nullable()();
  IntColumn get scheduledStart => integer().nullable()();
  IntColumn get scheduledEnd => integer().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}
