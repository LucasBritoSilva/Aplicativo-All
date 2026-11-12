import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/quick_form.dart';
import '../domain/break_logic.dart';

/// Id fixo da notificação de fim de período (fora das faixas dos
/// lembretes e da rotina).
const breakNotificationId = 900000001;

/// Grava o estado do cronômetro e agenda (ou cancela) o aviso de fim.
class BreakController {
  BreakController(this._settings, this._notifications);

  final SettingsRepository _settings;
  final NotificationService _notifications;

  Future<BreakState> load() async =>
      BreakState.decode(await _settings.read(SettingKeys.breakTimer));

  Future<void> save(BreakState state) async {
    await _settings.write(SettingKeys.breakTimer, state.encode());
    if (state.status == BreakStatus.running && state.endsAt != null) {
      await _notifications.schedule(
        id: breakNotificationId,
        title: state.phase == BreakPhase.focus
            ? 'Hora da pausa'
            : 'Fim da pausa',
        body: state.phase == BreakPhase.focus
            ? 'Terminou o período de foco. Que tal descansar ${state.restMinutes} min?'
            : 'A pausa acabou. Volte quando estiver pronto.',
        when: state.endsAt!,
        channel: AppChannel.breaks,
      );
    } else {
      await _notifications.cancel(breakNotificationId);
    }
  }
}

final breakControllerProvider = Provider<BreakController>(
  (ref) => BreakController(
    ref.watch(settingsRepositoryProvider),
    ref.watch(notificationServiceProvider),
  ),
);

final breakStateProvider = Provider<BreakState>(
  (ref) => BreakState.decode(
    ref.watch(settingProvider(SettingKeys.breakTimer)).value,
  ),
);

/// Pausas para descanso: períodos de foco e de pausa configuráveis.
///
/// Uma única notificação ao fim de cada período (se permitido). Não há
/// serviço rodando em segundo plano: o tempo é calculado pelo horário.
class BreakTimerScreen extends ConsumerWidget {
  const BreakTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(breakStateProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final controller = ref.read(breakControllerProvider);
    final today = epochDay(now);
    final remaining = state.remaining(now);
    final finished = state.finished(now);
    final isFocus = state.phase == BreakPhase.focus;
    final color = isFocus ? AppColors.primary : AppColors.success;

    Future<void> apply(BreakState next) => controller.save(next);

    Future<void> start() async {
      final permissions = ref.read(permissionServiceProvider);
      if (await permissions.notificationStatus() != PermissionState.granted) {
        await permissions.requestNotifications();
      }
      await apply(state.start(DateTime.now()));
    }

    Future<void> configure() async {
      final r = await showQuickForm(
        context,
        title: 'Configurar intervalos',
        fields: [
          NumberSpec(
            'focus',
            'Minutos de foco',
            initial: state.focusMinutes.toDouble(),
            required: true,
            decimal: false,
            min: 1,
            max: 600,
            suffix: 'min',
          ),
          NumberSpec(
            'rest',
            'Minutos de pausa',
            initial: state.restMinutes.toDouble(),
            required: true,
            decimal: false,
            min: 1,
            max: 240,
            suffix: 'min',
          ),
        ],
      );
      if (r == null) return;
      await apply(
        BreakState(
          focusMinutes: r.integer('focus')!,
          restMinutes: r.integer('rest')!,
          phase: state.phase,
          cycles: state.cycles,
          cyclesDay: state.cyclesDay,
        ),
      );
    }

    final total = state.phaseSeconds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pausas para descanso'),
        actions: [
          IconButton(
            tooltip: 'Configurar intervalos',
            icon: const Icon(Icons.tune),
            onPressed: state.status == BreakStatus.running ? null : configure,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Center(
            child: SegmentedButton<BreakPhase>(
              showSelectedIcon: false,
              segments: [
                for (final p in BreakPhase.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {state.phase},
              onSelectionChanged: state.status == BreakStatus.idle
                  ? (s) => apply(
                      state.phase == s.first
                          ? state
                          : state.next(today, completed: false),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: total == 0 ? 0 : 1 - remaining / total,
                    strokeWidth: 10,
                    backgroundColor: AppColors.surfaceHigh,
                    color: color,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatClock(remaining),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          finished
                              ? '${state.phase.label} terminado'
                              : switch (state.status) {
                                  BreakStatus.idle => 'Pronto para começar',
                                  BreakStatus.running => isFocus
                                      ? 'Em foco'
                                      : 'Descansando',
                                  BreakStatus.paused => 'Pausado',
                                },
                          style: TextStyle(color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (finished)
            FilledButton.icon(
              onPressed: () async {
                final next = state.next(today, completed: true);
                await apply(next.start(DateTime.now()));
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(isFocus ? 'Começar a pausa' : 'Voltar ao foco'),
            )
          else
            switch (state.status) {
              BreakStatus.idle => FilledButton.icon(
                onPressed: start,
                icon: const Icon(Icons.play_arrow),
                label: Text(isFocus ? 'Iniciar foco' : 'Iniciar pausa'),
              ),
              BreakStatus.running => FilledButton.icon(
                onPressed: () => apply(state.pause(DateTime.now())),
                icon: const Icon(Icons.pause),
                label: const Text('Pausar'),
              ),
              BreakStatus.paused => FilledButton.icon(
                onPressed: () => apply(state.resume(DateTime.now())),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Continuar'),
              ),
            },
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.status == BreakStatus.idle
                      ? null
                      : () => apply(state.reset()),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reiniciar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => apply(
                    state.next(today, completed: finished),
                  ),
                  icon: const Icon(Icons.skip_next),
                  label: Text(isFocus ? 'Pular para a pausa' : 'Pular a pausa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foco ${state.focusMinutes} min · pausa ${state.restMinutes} min',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Períodos de foco concluídos hoje: ${state.cyclesOn(today)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Você recebe um único aviso no fim de cada período, se as '
                    'notificações estiverem permitidas. O tempo continua '
                    'correndo mesmo fora desta tela.',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
