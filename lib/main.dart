import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/navigation/module_prefs.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings/settings_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/app_limits/ui/app_limits_screen.dart';
import 'features/reminders/data/reminders_repository.dart';
import 'features/routine/data/routine_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  String? launchPayload;

  // Tarefas de inicialização. Uma falha aqui não impede o app de abrir.
  try {
    // Cor escolhida pelo usuário, antes da primeira tela.
    final accent = parseAccent(
      await container
          .read(settingsRepositoryProvider)
          .read(SettingKeys.accentColor),
    );
    if (accent != null) AppColors.applyAccent(accent);
    final notifications = container.read(notificationServiceProvider);
    await notifications.init();
    launchPayload = await notifications.launchPayload();
    // Gera as ocorrências da rotina e confere as notificações (cobre dias
    // com o app fechado, mudança de fuso e atualização do app).
    await container.read(routineSyncProvider).run();
    // Confere se todo lembrete futuro está agendado.
    await container.read(reminderSchedulerProvider).resync();
  } catch (e) {
    debugPrint('Falha na inicialização: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: App(launchPayload: launchPayload),
    ),
  );

  // Religa o contador de uso de apps, se o usuário o deixou ligado (o
  // Android pode tê-lo encerrado, por exemplo ao reiniciar).
  try {
    final limits = container.read(appLimitsRepositoryProvider);
    if (await limits.monitorWanted()) await limits.applyMonitor();
  } catch (e) {
    debugPrint('Falha ao religar o monitor de uso: $e');
  }
}
