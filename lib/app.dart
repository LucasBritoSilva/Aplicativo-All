import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_modules.dart';
import 'core/navigation/home_screen.dart';
import 'core/navigation/recent_modules.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/today_provider.dart';
import 'features/routine/data/routine_sync.dart';
import 'features/routine/domain/routine_logic.dart';
import 'features/routine/ui/routine_screen.dart';

/// Navegador principal, usado para abrir a rotina ao tocar na notificação.
final appNavigatorKey = GlobalKey<NavigatorState>();

class App extends ConsumerStatefulWidget {
  const App({super.key, this.launchPayload});

  /// Conteúdo da notificação que abriu o app, se foi assim.
  final String? launchPayload;

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(notificationServiceProvider).taps.listen(_openPayload);
    final payload = widget.launchPayload;
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPayload(payload));
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  /// Notificação da rotina: abre a atividade correspondente.
  void _openPayload(String payload) {
    final occurrenceId = occurrenceIdFromPayload(payload);
    final navigator = appNavigatorKey.currentState;
    if (occurrenceId == null || navigator == null) return;
    ref.read(recentModulesProvider.notifier).registerAccess('rotina');
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineScreen(openOccurrenceId: occurrenceId),
        settings: const RouteSettings(name: 'rotina'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Virou o dia (ou o app voltou depois de muito tempo): gera as
    // ocorrências que faltam e confere as notificações.
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != next) ref.read(routineSyncProvider).run();
    });

    final theme = buildAppTheme();
    return MaterialApp(
      title: 'All',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}

/// Número de módulos do escopo confirmado (conferido nos testes).
int get confirmedModuleCount => appModules.where((m) => m.confirmed).length;
