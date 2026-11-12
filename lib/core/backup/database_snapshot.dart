import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'backup_codec.dart';

/// Exporta e importa o banco inteiro, tabela por tabela.
class DatabaseSnapshot {
  const DatabaseSnapshot(this._db);
  final AppDatabase _db;

  Future<BackupSnapshot> export() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _db.allTables) {
      final name = table.actualTableName;
      final rows = await _db.customSelect('SELECT * FROM "$name"').get();
      tables[name] = [for (final r in rows) Map<String, Object?>.of(r.data)];
    }
    return BackupSnapshot(
      schemaVersion: _db.schemaVersion,
      exportedAt: DateTime.now(),
      tables: tables,
    );
  }

  /// Substitui TODOS os dados locais pelos do backup, numa única transação:
  /// se algo der errado no meio, nada é alterado.
  Future<void> restore(BackupSnapshot snapshot) async {
    if (snapshot.schemaVersion > _db.schemaVersion) {
      throw const FormatException(
        'O backup foi feito por uma versão mais nova do app.',
      );
    }
    final tables = _db.allTables.toList();
    final byName = {for (final t in tables) t.actualTableName: t};

    // Valida tudo antes de apagar qualquer coisa.
    for (final entry in snapshot.tables.entries) {
      final table = byName[entry.key];
      if (table == null) {
        throw FormatException('Tabela desconhecida no backup: ${entry.key}.');
      }
      final columns = {for (final c in table.$columns) c.name};
      for (final row in entry.value) {
        for (final key in row.keys) {
          if (!columns.contains(key)) {
            throw FormatException(
              'Coluna desconhecida no backup: ${entry.key}.$key.',
            );
          }
        }
      }
    }

    await _db.transaction(() async {
      // Apaga primeiro as tabelas "filhas" (ordem inversa).
      for (final table in tables.reversed) {
        await _db.customUpdate(
          'DELETE FROM "${table.actualTableName}"',
          updates: {table},
          updateKind: UpdateKind.delete,
        );
      }
      // Insere primeiro as tabelas "pai".
      for (final table in tables) {
        final rows = snapshot.tables[table.actualTableName] ?? const [];
        for (final row in rows) {
          final keys = row.keys.toList();
          if (keys.isEmpty) continue;
          final cols = keys.map((k) => '"$k"').join(', ');
          final marks = List.filled(keys.length, '?').join(', ');
          await _db.customInsert(
            'INSERT INTO "${table.actualTableName}" ($cols) VALUES ($marks)',
            variables: [for (final k in keys) Variable<Object>(row[k])],
            updates: {table},
          );
        }
      }
    });
  }
}
