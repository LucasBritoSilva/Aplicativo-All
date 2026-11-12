import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/native/native_bridge.dart';

/// Conteúdo aberto de um registro do cofre. Só existe na memória enquanto
/// o cofre está destrancado; no banco fica apenas o texto cifrado.
class VaultRecord {
  const VaultRecord({
    required this.title,
    this.category,
    required this.content,
  });

  final String title;
  final String? category;
  final String content;

  String encode() => jsonEncode({'t': title, 'c': category, 'v': content});

  static VaultRecord? decode(String? plain) {
    if (plain == null) return null;
    try {
      final m = jsonDecode(plain) as Map<String, Object?>;
      return VaultRecord(
        title: (m['t'] as String?) ?? '',
        category: m['c'] as String?,
        content: (m['v'] as String?) ?? '',
      );
    } on Object {
      return null;
    }
  }
}

/// Registro decifrado com o id do banco. [record] nulo = ilegível (por
/// exemplo, se a chave do aparelho foi apagada).
class VaultItem {
  const VaultItem(this.entry, this.record);

  final VaultEntry entry;
  final VaultRecord? record;
}

class VaultLockedError implements Exception {
  const VaultLockedError();

  @override
  String toString() => 'O cofre está trancado.';
}

/// Cofre: cifra e decifra pelo lado nativo (Android Keystore) e guarda
/// somente o resultado cifrado no banco.
class VaultRepository {
  VaultRepository(this._db, this._native);

  final AppDatabase _db;
  final NativeBridge _native;

  Future<List<VaultItem>> loadAll() async {
    final entries = await (_db.select(
      _db.vaultEntries,
    )..orderBy([(e) => OrderingTerm.desc(e.updatedAt)])).get();
    if (entries.isEmpty) return const [];
    final plains = await _native.vaultDecryptAll([
      for (final e in entries) e.payload,
    ]);
    return [
      for (final (i, e) in entries.indexed)
        VaultItem(e, VaultRecord.decode(i < plains.length ? plains[i] : null)),
    ];
  }

  Future<void> save({int? id, required VaultRecord record}) async {
    final payload = await _native.vaultEncrypt(record.encode());
    if (payload == null) throw const VaultLockedError();
    if (id == null) {
      await _db
          .into(_db.vaultEntries)
          .insert(VaultEntriesCompanion.insert(payload: payload));
    } else {
      await (_db.update(_db.vaultEntries)..where((e) => e.id.equals(id))).write(
        VaultEntriesCompanion(
          payload: Value(payload),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.vaultEntries)..where((e) => e.id.equals(id))).go();

  /// Apaga todos os registros e a chave. Não pode ser desfeito.
  Future<void> wipe() async {
    await _db.delete(_db.vaultEntries).go();
    await _native.vaultReset();
  }

  Future<int> count() async =>
      (await _db.select(_db.vaultEntries).get()).length;
}

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(
    ref.watch(databaseProvider),
    ref.watch(nativeBridgeProvider),
  ),
);
