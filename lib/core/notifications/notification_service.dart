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

/// Serviço central de notificações locais.
///
/// Os horários são convertidos para UTC antes de agendar: um lembrete é um
/// instante único, então não depende do fuso do aparelho (ver DECISOES.md).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'lembretes',
    'Lembretes',
    description: 'Avisos dos lembretes agendados no app',
    importance: Importance.high,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      );
      await _android?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('Falha ao iniciar notificações: $e');
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
  }) async {
    await init();
    if (!when.isAfter(DateTime.now())) return ScheduleOutcome.past;

    final exact = await canScheduleExact();
    final scheduled = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'lembretes',
        'Lembretes',
        channelDescription: 'Avisos dos lembretes agendados no app',
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
  Future<Set<int>> pendingIds() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.map((p) => p.id).toSet();
    } catch (_) {
      return <int>{};
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
