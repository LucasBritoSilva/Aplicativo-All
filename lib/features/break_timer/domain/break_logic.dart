import 'dart:convert';

/// Período atual do ciclo de pausas.
enum BreakPhase {
  focus('Foco'),
  rest('Pausa');

  const BreakPhase(this.label);
  final String label;
}

enum BreakStatus { idle, running, paused }

/// Estado do cronômetro de pausas. Fica gravado no banco, então continua
/// certo depois de sair da tela ou fechar o app: o tempo restante é
/// sempre calculado a partir do horário de término gravado.
class BreakState {
  const BreakState({
    this.focusMinutes = 50,
    this.restMinutes = 10,
    this.phase = BreakPhase.focus,
    this.status = BreakStatus.idle,
    this.endsAt,
    this.pausedRemaining,
    this.cycles = 0,
    this.cyclesDay,
  });

  final int focusMinutes;
  final int restMinutes;
  final BreakPhase phase;
  final BreakStatus status;

  /// Fim do período em andamento (só quando [status] é running).
  final DateTime? endsAt;

  /// Segundos que faltavam quando foi pausado.
  final int? pausedRemaining;

  /// Períodos de foco concluídos em [cyclesDay].
  final int cycles;
  final int? cyclesDay;

  int get phaseSeconds =>
      (phase == BreakPhase.focus ? focusMinutes : restMinutes) * 60;

  /// Segundos restantes no período (nunca negativo).
  int remaining(DateTime now) {
    switch (status) {
      case BreakStatus.idle:
        return phaseSeconds;
      case BreakStatus.paused:
        return pausedRemaining ?? phaseSeconds;
      case BreakStatus.running:
        final left = endsAt!.difference(now).inSeconds;
        return left < 0 ? 0 : left;
    }
  }

  /// O período em andamento já terminou e espera o usuário seguir.
  bool finished(DateTime now) =>
      status == BreakStatus.running && !endsAt!.isAfter(now);

  int cyclesOn(int day) => cyclesDay == day ? cycles : 0;

  BreakState copyWith({
    int? focusMinutes,
    int? restMinutes,
    BreakPhase? phase,
    BreakStatus? status,
    DateTime? Function()? endsAt,
    int? Function()? pausedRemaining,
    int? cycles,
    int? Function()? cyclesDay,
  }) => BreakState(
    focusMinutes: focusMinutes ?? this.focusMinutes,
    restMinutes: restMinutes ?? this.restMinutes,
    phase: phase ?? this.phase,
    status: status ?? this.status,
    endsAt: endsAt == null ? this.endsAt : endsAt(),
    pausedRemaining: pausedRemaining == null
        ? this.pausedRemaining
        : pausedRemaining(),
    cycles: cycles ?? this.cycles,
    cyclesDay: cyclesDay == null ? this.cyclesDay : cyclesDay(),
  );

  // ---- transições ----

  BreakState start(DateTime now) => copyWith(
    status: BreakStatus.running,
    endsAt: () => now.add(Duration(seconds: phaseSeconds)),
    pausedRemaining: () => null,
  );

  BreakState pause(DateTime now) => status != BreakStatus.running
      ? this
      : copyWith(
          status: BreakStatus.paused,
          pausedRemaining: () => remaining(now),
          endsAt: () => null,
        );

  BreakState resume(DateTime now) => status != BreakStatus.paused
      ? this
      : copyWith(
          status: BreakStatus.running,
          endsAt: () => now.add(Duration(seconds: remaining(now))),
          pausedRemaining: () => null,
        );

  /// Volta o período atual ao início, parado.
  BreakState reset() => copyWith(
    status: BreakStatus.idle,
    endsAt: () => null,
    pausedRemaining: () => null,
  );

  /// Passa para o próximo período (parado). Terminar um foco conta um ciclo.
  BreakState next(int today, {required bool completed}) {
    final countCycle = completed && phase == BreakPhase.focus;
    final base = cyclesDay == today ? cycles : 0;
    return BreakState(
      focusMinutes: focusMinutes,
      restMinutes: restMinutes,
      phase: phase == BreakPhase.focus ? BreakPhase.rest : BreakPhase.focus,
      cycles: countCycle ? base + 1 : base,
      cyclesDay: today,
    );
  }

  Map<String, Object?> toJson() => {
    'focus': focusMinutes,
    'rest': restMinutes,
    'phase': phase.name,
    'status': status.name,
    'endsAt': endsAt?.millisecondsSinceEpoch,
    'paused': pausedRemaining,
    'cycles': cycles,
    'cyclesDay': cyclesDay,
  };

  String encode() => jsonEncode(toJson());

  static BreakState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const BreakState();
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      final status = BreakStatus.values.asNameMap()[m['status']] ?? BreakStatus.idle;
      final endsAtMs = m['endsAt'] as int?;
      return BreakState(
        focusMinutes: (m['focus'] as int?) ?? 50,
        restMinutes: (m['rest'] as int?) ?? 10,
        phase: BreakPhase.values.asNameMap()[m['phase']] ?? BreakPhase.focus,
        status: status == BreakStatus.running && endsAtMs == null
            ? BreakStatus.idle
            : status,
        endsAt: endsAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(endsAtMs),
        pausedRemaining: m['paused'] as int?,
        cycles: (m['cycles'] as int?) ?? 0,
        cyclesDay: m['cyclesDay'] as int?,
      );
    } on Object {
      return const BreakState();
    }
  }
}
