import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Situação simplificada de uma permissão.
enum PermissionState {
  granted,
  denied,

  /// Negada de vez: só dá para liberar nas configurações do Android.
  blocked,
}

PermissionState _map(PermissionStatus s) {
  if (s.isGranted || s.isLimited) return PermissionState.granted;
  if (s.isPermanentlyDenied || s.isRestricted) return PermissionState.blocked;
  return PermissionState.denied;
}

/// Pedidos de permissão em tempo de execução, em um só lugar.
class PermissionService {
  const PermissionService();

  /// POST_NOTIFICATIONS (Android 13+).
  Future<PermissionState> notificationStatus() async =>
      _map(await Permission.notification.status);

  Future<PermissionState> requestNotifications() async =>
      _map(await Permission.notification.request());

  /// Alarmes exatos (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM).
  Future<bool> exactAlarmsAllowed() async =>
      (await Permission.scheduleExactAlarm.status).isGranted;

  /// Abre a tela do Android onde o usuário libera alarmes exatos.
  Future<bool> requestExactAlarms() async =>
      (await Permission.scheduleExactAlarm.request()).isGranted;

  /// RECORD_AUDIO, para a captura de ideias por voz.
  Future<PermissionState> microphoneStatus() async =>
      _map(await Permission.microphone.status);

  Future<PermissionState> requestMicrophone() async =>
      _map(await Permission.microphone.request());

  /// Abre a tela de configurações do app no Android.
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);
