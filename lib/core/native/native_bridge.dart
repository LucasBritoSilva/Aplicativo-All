import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Situação do cofre no lado nativo.
enum VaultState {
  /// O aparelho não respondeu (por exemplo, em testes fora do Android).
  unavailable,

  /// O Android não tem bloqueio de tela (PIN, padrão ou senha).
  noLockScreen,

  /// O cofre ainda não foi criado neste aparelho.
  notCreated,

  /// Criado e trancado.
  locked,

  /// Destrancado: a chave está na memória.
  unlocked,
}

/// Resultado de uma tentativa de destrancar o cofre.
enum VaultUnlockResult {
  ok,
  canceled,
  noLockScreen,

  /// A chave foi invalidada pelo Android (bloqueio de tela removido).
  invalidated,
  error,
}

/// Um aplicativo instalado que pode ser aberto pelo usuário.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.icon,
  });

  final String packageName;
  final String label;

  /// Ícone em PNG.
  final Uint8List? icon;
}

/// Ponte com o código Kotlin do app (canal `aplicativo_all/native`).
///
/// Reúne o que depende do Android e não tem pacote Dart no projeto: abrir
/// links e o discador, o cofre (Android Keystore e biometria) e o uso de
/// aplicativos (UsageStats e sobreposição). Toda chamada trata a falta do
/// lado nativo devolvendo um valor seguro, para o app nunca travar.
class NativeBridge {
  const NativeBridge([
    this._channel = const MethodChannel('aplicativo_all/native'),
  ]);

  final MethodChannel _channel;

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      // Nunca registrar argumentos: podem conter dados do cofre.
      debugPrint('Falha nativa em $method: ${e.code}');
      return null;
    }
  }

  // ---- Links, telefone e área de transferência ----

  /// Abre um endereço no app padrão. Falso se não houver app compatível.
  Future<bool> openUrl(String url) async =>
      await _call<bool>('openUrl', {'url': url}) ?? false;

  /// Abre o discador com o número preenchido (não liga sozinho).
  Future<bool> dial(String phone) async =>
      await _call<bool>('dial', {'phone': phone}) ?? false;

  /// Copia um texto marcando-o como sensível (não aparece na prévia).
  Future<void> copySensitive(String text) =>
      _call<void>('copySensitive', {'text': text});

  /// Liga ou desliga a proteção contra capturas de tela e recentes.
  Future<void> setSecureScreen(bool enabled) =>
      _call<void>('setSecure', {'enabled': enabled});

  // ---- Imagens das notas ----

  /// Abre o seletor de fotos e devolve os caminhos das cópias guardadas na
  /// pasta privada do app (lista vazia se o usuário cancelar).
  Future<List<String>> pickImages() async {
    try {
      final paths = await _channel.invokeListMethod<String>('pickImages');
      return paths ?? const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Falha ao escolher imagens: ${e.code}');
      return const [];
    }
  }

  /// Apaga imagens da pasta privada do app (só as das notas).
  Future<void> deleteFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    await _call<void>('deleteFiles', {'paths': paths});
  }

  // ---- Alarmes exatos ----

  /// Se o Android deixa o app agendar alarmes no minuto exato.
  /// Sem o lado nativo (testes), considera permitido.
  Future<bool> canScheduleExactAlarms() async =>
      await _call<bool>('canScheduleExactAlarms') ?? true;

  /// Abre a tela "Alarmes e lembretes" (Android 12+). Falso se não houver.
  Future<bool> openExactAlarmSettings() async =>
      await _call<bool>('openExactAlarmSettings') ?? false;

  // ---- Cofre ----

  Future<VaultState> vaultState() async {
    return switch (await _call<String>('vaultState')) {
      'no_lock_screen' => VaultState.noLockScreen,
      'not_created' => VaultState.notCreated,
      'locked' => VaultState.locked,
      'unlocked' => VaultState.unlocked,
      _ => VaultState.unavailable,
    };
  }

  /// Pede biometria ou a credencial do aparelho e destranca o cofre.
  /// Na primeira vez, cria a chave.
  Future<VaultUnlockResult> vaultUnlock() async {
    return switch (await _call<String>('vaultUnlock')) {
      'ok' => VaultUnlockResult.ok,
      'canceled' => VaultUnlockResult.canceled,
      'no_lock_screen' => VaultUnlockResult.noLockScreen,
      'invalidated' => VaultUnlockResult.invalidated,
      _ => VaultUnlockResult.error,
    };
  }

  /// Apaga a chave da memória.
  Future<void> vaultLock() => _call<void>('vaultLock');

  /// Apaga a chave do cofre para sempre (os registros ficam ilegíveis).
  Future<void> vaultReset() => _call<void>('vaultReset');

  /// Cifra um texto. Nulo se o cofre estiver trancado.
  Future<String?> vaultEncrypt(String plain) =>
      _call<String>('vaultEncrypt', {'plain': plain});

  /// Decifra vários textos de uma vez. Itens ilegíveis voltam nulos.
  Future<List<String?>> vaultDecryptAll(List<String> payloads) async {
    try {
      final result = await _channel.invokeListMethod<String?>(
        'vaultDecryptAll',
        {'payloads': payloads},
      );
      return result ?? List<String?>.filled(payloads.length, null);
    } on MissingPluginException {
      return List<String?>.filled(payloads.length, null);
    } on PlatformException catch (e) {
      debugPrint('Falha nativa em vaultDecryptAll: ${e.code}');
      return List<String?>.filled(payloads.length, null);
    }
  }

  // ---- Uso de aplicativos ----

  /// Se o usuário liberou o "Acesso ao uso" para o app.
  Future<bool> hasUsageAccess() async =>
      await _call<bool>('hasUsageAccess') ?? false;

  Future<void> openUsageAccessSettings() =>
      _call<void>('openUsageAccessSettings');

  /// Se o app pode desenhar sobre outros apps (contador flutuante).
  Future<bool> canDrawOverlays() async =>
      await _call<bool>('canDrawOverlays') ?? false;

  Future<void> openOverlaySettings() => _call<void>('openOverlaySettings');

  /// Aplicativos com ícone na tela inicial do aparelho.
  Future<List<InstalledApp>> installedApps() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'installedApps',
      );
      final apps = [
        for (final m in raw ?? const <Map<Object?, Object?>>[])
          InstalledApp(
            packageName: m['package'] as String,
            label: (m['label'] as String?) ?? (m['package'] as String),
            icon: m['icon'] as Uint8List?,
          ),
      ];
      apps.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return apps;
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Falha nativa em installedApps: ${e.code}');
      return const [];
    }
  }

  /// Tempo de uso de hoje, em milissegundos, por pacote.
  Future<Map<String, int>> usageToday() async {
    try {
      final raw = await _channel.invokeMapMethod<String, int>('usageToday');
      return raw ?? const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException catch (e) {
      debugPrint('Falha nativa em usageToday: ${e.code}');
      return const {};
    }
  }

  /// Envia os limites ao serviço nativo e liga ou desliga o monitor.
  /// [limits] é pacote -> minutos por dia; [modes] é pacote -> 'overlay'
  /// (contador flutuante) ou 'notify' (notificação ao atingir o limite).
  Future<bool> configureMonitor({
    required bool enabled,
    required Map<String, int> limits,
    Map<String, String> modes = const {},
  }) async =>
      await _call<bool>('configureMonitor', {
        'enabled': enabled,
        'limits': limits,
        'modes': modes,
      }) ??
      false;

  Future<bool> monitorRunning() async =>
      await _call<bool>('monitorRunning') ?? false;
}

final nativeBridgeProvider = Provider<NativeBridge>(
  (ref) => const NativeBridge(),
);
