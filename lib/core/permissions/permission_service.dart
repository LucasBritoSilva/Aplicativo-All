import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../native/native_bridge.dart';

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
  const PermissionService(this._native);

  final NativeBridge _native;

  /// POST_NOTIFICATIONS (Android 13+).
  Future<PermissionState> notificationStatus() async =>
      _map(await Permission.notification.status);

  Future<PermissionState> requestNotifications() async =>
      _map(await Permission.notification.request());

  /// Alarmes exatos, consultados direto no AlarmManager.
  ///
  /// O permission_handler não serve aqui: a SCHEDULE_EXACT_ALARM só é
  /// declarada até o Android 12 (no 13+ o app usa USE_EXACT_ALARM), e o
  /// plugin a trata como "não declarada" e nunca abre a tela certa.
  Future<bool> exactAlarmsAllowed() => _native.canScheduleExactAlarms();

  /// Abre a tela "Alarmes e lembretes". O resultado só é conhecido quando o
  /// usuário volta ao app (quem chamou confere de novo ao retomar).
  Future<bool> requestExactAlarms() => _native.openExactAlarmSettings();

  /// RECORD_AUDIO, para a captura de ideias por voz.
  Future<PermissionState> microphoneStatus() async =>
      _map(await Permission.microphone.status);

  Future<PermissionState> requestMicrophone() async =>
      _map(await Permission.microphone.request());

  /// Abre a tela de configurações do app no Android.
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(ref.watch(nativeBridgeProvider)),
);
