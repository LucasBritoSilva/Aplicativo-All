import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'features/reminders/data/reminders_repository.dart';
import 'features/routine/data/routine_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  // Tarefas de inicialização. Uma falha aqui não impede o app de abrir.
  try {
    await container.read(notificationServiceProvider).init();
    await container.read(routineRepositoryProvider).resetStale(DateTime.now());
    // Confere se todo lembrete futuro está agendado (ex.: após atualizar o app).
    await container.read(reminderSchedulerProvider).resync();
  } catch (e) {
    debugPrint('Falha na inicialização: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
