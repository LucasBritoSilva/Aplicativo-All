import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Resultado de um agendamento.
enum ScheduleOutcome {
  /// Agendado em horário exato.
  exact,

  /// Agendado como alarme inexato (pode atrasar alguns minutos), porque o
  /// alarme exato não está permitido no celular.
  inexact,

  /// O horário já passou; nada foi agendado.
  past,

  /// O sistema recusou o agendamento.
  failed,
}

/// Canais de notificação do app. O usuário pode silenciar cada um
/// separadamente nas configurações do Android.
enum AppChannel {
  reminders('lembretes', 'Lembretes', 'Avisos dos lembretes agendados no app'),
  routine('rotina', 'Rotina', 'Aviso no horário de início de cada atividade'),
  breaks('pausas', 'Pausas', 'Aviso do fim do período de foco ou de pausa');

  const AppChannel(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}

/// Serviço central de notificações locais.
///
/// Os horários são convertidos para UTC antes de agendar: cada aviso é um
/// instante único. Os horários da rotina (que seguem o relógio local) são
/// recalculados sempre que o app abre, o que cobre mudança de fuso.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  /// Conteúdo (payload) das notificações tocadas com o app aberto.
  Stream<String> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(payload);
        },
      );
      for (final c in AppChannel.values) {
        await _android?.createNotificationChannel(
          AndroidNotificationChannel(
            c.id,
            c.title,
            description: c.description,
            importance: Importance.high,
          ),
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Falha ao iniciar notificações: $e');
    }
  }

  /// Payload da notificação que abriu o app (quando ele estava fechado).
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return details.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  /// Se o app pode mostrar notificações (Android 13+ exige permissão).
  Future<bool> notificationsEnabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Se o celular permite alarmes exatos para este app.
  Future<bool> canScheduleExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Agenda (ou reagenda, se o [id] já existir) uma notificação.
  Future<ScheduleOutcome> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime when,
    String? payload,
    AppChannel channel = AppChannel.reminders,
  }) async {
    await init();
    if (!when.isAfter(DateTime.now())) return ScheduleOutcome.past;

    final exact = await canScheduleExact();
    final scheduled = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.title,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );

    Future<void> run(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: mode,
      payload: payload,
    );

    try {
      if (exact) {
        await run(AndroidScheduleMode.exactAllowWhileIdle);
        return ScheduleOutcome.exact;
      }
      await run(AndroidScheduleMode.inexactAllowWhileIdle);
      return ScheduleOutcome.inexact;
    } on PlatformException catch (e) {
      // Se a permissão de alarme exato foi revogada no meio do caminho,
      // tenta de novo como alarme inexato.
      debugPrint('Agendamento exato recusado: $e');
      try {
        await run(AndroidScheduleMode.inexactAllowWhileIdle);
        return ScheduleOutcome.inexact;
      } catch (e2) {
        debugPrint('Agendamento inexato recusado: $e2');
        return ScheduleOutcome.failed;
      }
    } catch (e) {
      debugPrint('Falha ao agendar: $e');
      return ScheduleOutcome.failed;
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Falha ao cancelar notificação $id: $e');
    }
  }

  /// Ids das notificações agendadas que ainda não dispararam.
  Future<Set<int>> pendingIds() async => (await pendingPayloads()).keys.toSet();

  /// Notificações agendadas: id e o conteúdo (payload) de cada uma.
  Future<Map<int, String?>> pendingPayloads() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return {for (final p in pending) p.id: p.payload};
    } catch (_) {
      return <int, String?>{};
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
