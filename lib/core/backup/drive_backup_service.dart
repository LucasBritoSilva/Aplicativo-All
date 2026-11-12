import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import 'backup_codec.dart';
import 'backup_config.dart';
import 'database_snapshot.dart';

/// Erro com mensagem pronta para mostrar ao usuário.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Dados do arquivo de backup que está no Drive.
class RemoteBackupInfo {
  const RemoteBackupInfo({required this.id, this.modifiedTime});
  final String id;
  final DateTime? modifiedTime;
}

/// Backup manual no Google Drive.
///
/// O arquivo fica na "pasta do app" do Drive (appDataFolder): uma área
/// privada, que só este app enxerga, e que não aparece na lista de
/// arquivos do usuário. Só há comunicação com o Google quando o usuário
/// toca em "Fazer backup" ou "Restaurar".
class DriveBackupService {
  DriveBackupService(this._db);

  final AppDatabase _db;
  static const fileName = 'app_pessoal_backup.json';
  static const _scopes = [drive.DriveApi.driveAppdataScope];
  bool _initialized = false;

  Future<void> _ensureConfigured() async {
    final config = await BackupConfig.load();
    if (!config.isConfigured) {
      throw const BackupException(
        'O backup ainda não foi configurado. Falta colar o ID do cliente '
        'OAuth no arquivo de configuração (veja PENDENCIAS.md, etapa b).',
      );
    }
    if (!_initialized) {
      await GoogleSignIn.instance.initialize();
      _initialized = true;
    }
  }

  /// Pede autorização (mostra a tela do Google na primeira vez) e roda
  /// [action] com acesso ao Drive. Se o token tiver expirado, tenta de novo
  /// uma vez com um token novo.
  Future<T> _withDrive<T>(Future<T> Function(drive.DriveApi api) action) async {
    await _ensureConfigured();
    final authClient = GoogleSignIn.instance.authorizationClient;
    for (var attempt = 0; attempt < 2; attempt++) {
      final GoogleSignInClientAuthorization authz;
      try {
        authz =
            await authClient.authorizationForScopes(_scopes) ??
            await authClient.authorizeScopes(_scopes);
      } on GoogleSignInException catch (e) {
        throw BackupException(_signInMessage(e));
      }
      final client = _BearerClient(authz.accessToken);
      try {
        return await action(drive.DriveApi(client));
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 401 && attempt == 0) {
          await authClient.clearAuthorizationToken(
            accessToken: authz.accessToken,
          );
          continue;
        }
        throw BackupException(_apiMessage(e));
      } on SocketException {
        throw const BackupException(
          'Sem conexão com a internet. Verifique o Wi-Fi ou os dados móveis.',
        );
      } on http.ClientException {
        throw const BackupException(
          'Sem conexão com a internet. Verifique o Wi-Fi ou os dados móveis.',
        );
      } on TimeoutException {
        throw const BackupException('O Google Drive demorou para responder.');
      } finally {
        client.close();
      }
    }
    throw const BackupException('Não foi possível acessar o Google Drive.');
  }

  Future<RemoteBackupInfo?> _find(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName' and trashed = false",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id, modifiedTime)',
    );
    final files = list.files ?? const <drive.File>[];
    if (files.isEmpty || files.first.id == null) return null;
    return RemoteBackupInfo(
      id: files.first.id!,
      modifiedTime: files.first.modifiedTime?.toLocal(),
    );
  }

  /// Informa se já existe um backup no Drive (e quando foi feito).
  Future<RemoteBackupInfo?> findBackup() => _withDrive(_find);

  /// Exporta o banco como JSON e grava no Drive (substitui o anterior).
  Future<DateTime> backup() async {
    final snapshot = await DatabaseSnapshot(_db).export();
    final bytes = utf8.encode(snapshot.encode());
    return _withDrive((api) async {
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );
      final existing = await _find(api);
      if (existing == null) {
        await api.files.create(
          drive.File()
            ..name = fileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      } else {
        await api.files.update(drive.File(), existing.id, uploadMedia: media);
      }
      return snapshot.exportedAt;
    });
  }

  /// Baixa e valida o backup do Drive, sem alterar nada no celular.
  Future<BackupSnapshot> download() => _withDrive((api) async {
    final info = await _find(api);
    if (info == null) {
      throw const BackupException(
        'Nenhum backup encontrado no Google Drive desta conta.',
      );
    }
    final media =
        await api.files.get(
              info.id,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    try {
      return BackupSnapshot.decode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw BackupException(e.message);
    }
  });

  /// Substitui os dados locais pelo backup baixado.
  /// Só deve ser chamado depois da confirmação do usuário.
  Future<void> restore(BackupSnapshot snapshot) async {
    try {
      await DatabaseSnapshot(_db).restore(snapshot);
    } on FormatException catch (e) {
      throw BackupException(e.message);
    }
  }

  static String _signInMessage(GoogleSignInException e) {
    debugPrint('GoogleSignInException: ${e.code} ${e.description}');
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled =>
        'Acesso ao Google cancelado. Se você escolheu a conta e mesmo assim '
            'apareceu esta mensagem, confira a configuração do Google Cloud '
            '(nome do pacote e SHA-1) em PENDENCIAS.md.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Configuração do Google incompleta. Confira o cliente OAuth Android '
            '(nome do pacote e SHA-1) em PENDENCIAS.md.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Não foi possível abrir a tela de login do Google.',
      _ =>
        'Não foi possível acessar sua conta Google'
            '${e.description == null ? '' : ' (${e.description})'}.',
    };
  }

  static String _apiMessage(drive.DetailedApiRequestError e) {
    debugPrint('Drive API: ${e.status} ${e.message}');
    if (e.status == 403) {
      return 'O Google recusou o acesso ao Drive. Confira se a Google Drive '
          'API está ativada no projeto do Google Cloud.';
    }
    return 'Erro do Google Drive (${e.status}): ${e.message}';
  }
}

/// Cliente HTTP que envia o token de acesso em cada pedido ao Drive.
class _BearerClient extends http.BaseClient {
  _BearerClient(this._token);
  final String _token;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final driveBackupServiceProvider = Provider<DriveBackupService>(
  (ref) => DriveBackupService(ref.watch(databaseProvider)),
);

final backupConfigProvider = FutureProvider<BackupConfig>(
  (ref) => BackupConfig.load(),
);
