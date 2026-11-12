import 'dart:convert';

/// Conteúdo de um backup: todas as tabelas do banco, linha por linha.
///
/// Formato do arquivo JSON:
/// ```json
/// {
///   "app": "app_pessoal",
///   "format": 1,
///   "schemaVersion": 1,
///   "exportedAt": "2026-11-11T17:30:00.000Z",
///   "tables": { "tasks": [ { "id": 1, "title": "..." } ], ... }
/// }
/// ```
class BackupSnapshot {
  const BackupSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required this.tables,
  });

  static const appId = 'app_pessoal';
  static const formatVersion = 1;

  /// Versão do banco que gerou o backup.
  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, List<Map<String, Object?>>> tables;

  int get totalRows => tables.values.fold(0, (sum, rows) => sum + rows.length);

  String encode() => jsonEncode({
    'app': appId,
    'format': formatVersion,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'tables': tables,
  });

  /// Lê e valida um backup. Lança [FormatException] se o arquivo não for
  /// um backup válido deste app.
  static BackupSnapshot decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const FormatException('O arquivo de backup está corrompido.');
    }
    if (json is! Map<String, dynamic> || json['app'] != appId) {
      throw const FormatException('O arquivo não é um backup do App Pessoal.');
    }
    final format = json['format'];
    if (format is! int || format > formatVersion) {
      throw const FormatException(
        'O backup foi feito por uma versão mais nova do app.',
      );
    }
    final schema = json['schemaVersion'];
    final exported = DateTime.tryParse('${json['exportedAt']}');
    final rawTables = json['tables'];
    if (schema is! int || exported == null || rawTables is! Map) {
      throw const FormatException('O arquivo de backup está incompleto.');
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in rawTables.entries) {
      final rows = entry.value;
      if (entry.key is! String || rows is! List) {
        throw const FormatException('Tabela inválida no backup.');
      }
      tables[entry.key as String] = [
        for (final row in rows) _row(row, entry.key as String),
      ];
    }
    return BackupSnapshot(
      schemaVersion: schema,
      exportedAt: exported.toLocal(),
      tables: tables,
    );
  }

  static Map<String, Object?> _row(Object? row, String table) {
    if (row is! Map) {
      throw FormatException('Linha inválida na tabela $table.');
    }
    final out = <String, Object?>{};
    for (final e in row.entries) {
      final v = e.value;
      if (e.key is! String ||
          !(v == null || v is int || v is double || v is String || v is bool)) {
        throw FormatException('Valor inválido na tabela $table.');
      }
      out[e.key as String] = v;
    }
    return out;
  }
}
