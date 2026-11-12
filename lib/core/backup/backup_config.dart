import 'dart:convert';

import 'package:flutter/services.dart';

/// Configuração do backup no Google Drive, lida de
/// `assets/config/google_drive.json`.
///
/// No Android, o Google reconhece o app pelo nome do pacote e pela
/// impressão digital SHA-1 cadastrados no cliente OAuth do tipo Android.
/// O ID desse cliente fica neste arquivo para registrar qual cliente foi
/// criado e para o app saber que o backup já foi configurado.
class BackupConfig {
  const BackupConfig({required this.androidClientId});

  static const assetPath = 'assets/config/google_drive.json';
  static const _suffix = '.apps.googleusercontent.com';

  final String androidClientId;

  bool get isConfigured {
    final id = androidClientId.trim();
    return id.length > _suffix.length && id.endsWith(_suffix);
  }

  /// Interpreta o conteúdo do arquivo. Conteúdo inválido = não configurado.
  static BackupConfig parse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is Map<String, dynamic>) {
        final id = json['android_client_id'];
        if (id is String) return BackupConfig(androidClientId: id.trim());
      }
    } on FormatException {
      // cai no retorno abaixo
    }
    return const BackupConfig(androidClientId: '');
  }

  static Future<BackupConfig> load([AssetBundle? bundle]) async {
    try {
      final source = await (bundle ?? rootBundle).loadString(assetPath);
      return parse(source);
    } catch (_) {
      return const BackupConfig(androidClientId: '');
    }
  }
}
