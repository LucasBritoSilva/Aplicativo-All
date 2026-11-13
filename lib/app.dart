import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_modules.dart';
import 'core/navigation/home_screen.dart';
import 'core/navigation/module_prefs.dart';
import 'core/navigation/recent_modules.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/today_provider.dart';
import 'core/widgets/app_footer.dart';
import 'features/reminders/data/reminders_repository.dart';
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
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Ao voltar para o app (por exemplo, das configurações do Android), as
    // permissões podem ter mudado: reagenda avisos no modo certo.
    _lifecycle = AppLifecycleListener(onResume: _resyncNotifications);
    _taps = ref.read(notificationServiceProvider).taps.listen(_openPayload);
    final payload = widget.launchPayload;
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPayload(payload),
      );
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _resyncNotifications() async {
    try {
      await ref.read(reminderSchedulerProvider).resync();
      await ref.read(routineSyncProvider).syncNotifications();
    } catch (e) {
      debugPrint('Falha ao reagendar avisos: $e');
    }
  }

  /// Redesenha todas as telas, para a nova cor valer também nas que usam
  /// [AppColors] diretamente (sem depender do tema).
  void _rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    final root = appNavigatorKey.currentContext;
    if (root is Element) {
      visit(root);
    } else if (mounted) {
      (context as Element).visitChildren(visit);
    }
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

    // Cor de destaque escolhida em Configurações: vale na hora, em todas
    // as telas abertas (inclusive as que ficaram embaixo de outras).
    final accent = ref.watch(accentColorProvider);
    if (accent.toARGB32() != AppColors.primary.toARGB32()) {
      AppColors.applyAccent(accent);
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }

    final theme = buildAppTheme();
    return MaterialApp(
      title: 'BrutAll',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          WithAppFooter(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}

/// Número de módulos do escopo confirmado (conferido nos testes).
int get confirmedModuleCount => appModules.where((m) => m.confirmed).length;
