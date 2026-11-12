import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

class WishesData {
  const WishesData(this.folders, this.items);

  final List<WishFolder> folders;
  final List<WishItem> items;

  List<WishItem> itemsIn(int? folderId) =>
      items.where((i) => i.folderId == folderId).toList();
}

/// Lista de desejos com pastas (setores) personalizadas.
class WishesRepository {
  WishesRepository(this._db);
  final AppDatabase _db;

  Future<WishesData> _load() async {
    final folders =
        await (_db.select(_db.wishFolders)..orderBy([
              (f) => OrderingTerm.asc(f.name.collate(Collate.noCase)),
            ]))
            .get();
    final items =
        await (_db.select(_db.wishItems)..orderBy([
              (i) => OrderingTerm.asc(i.acquired),
              (i) => OrderingTerm.desc(i.createdAt),
            ]))
            .get();
    return WishesData(folders, items);
  }

  Stream<WishesData> watch() =>
      _db.watchTables({_db.wishFolders, _db.wishItems}, _load);

  Future<int> createFolder(String name) => _db
      .into(_db.wishFolders)
      .insert(WishFoldersCompanion.insert(name: name.trim()));

  Future<void> renameFolder(int id, String name) =>
      (_db.update(_db.wishFolders)..where((f) => f.id.equals(id))).write(
        WishFoldersCompanion(name: Value(name.trim())),
      );

  /// Exclui a pasta sem perder itens: eles vão para [moveTo] (ou ficam
  /// "Sem pasta" quando [moveTo] é nulo).
  Future<void> deleteFolder(int id, {int? moveTo}) => _db.transaction(() async {
    if (moveTo == id) {
      throw ArgumentError('O destino não pode ser a própria pasta.');
    }
    await (_db.update(_db.wishItems)..where((i) => i.folderId.equals(id)))
        .write(WishItemsCompanion(folderId: Value(moveTo)));
    await (_db.delete(_db.wishFolders)..where((f) => f.id.equals(id))).go();
  });

  Future<void> saveItem({
    int? id,
    required String name,
    String? link,
    double? price,
    String? notes,
    int? folderId,
  }) async {
    final data = WishItemsCompanion(
      name: Value(name),
      link: Value(link),
      price: Value(price),
      notes: Value(notes),
      folderId: Value(folderId),
    );
    if (id == null) {
      await _db.into(_db.wishItems).insert(data);
    } else {
      await (_db.update(
        _db.wishItems,
      )..where((i) => i.id.equals(id))).write(data);
    }
  }

  Future<void> moveItem(int id, int? folderId) =>
      (_db.update(_db.wishItems)..where((i) => i.id.equals(id))).write(
        WishItemsCompanion(folderId: Value(folderId)),
      );

  Future<void> setAcquired(int id, bool acquired) =>
      (_db.update(_db.wishItems)..where((i) => i.id.equals(id))).write(
        WishItemsCompanion(acquired: Value(acquired)),
      );

  Future<void> deleteItem(int id) =>
      (_db.delete(_db.wishItems)..where((i) => i.id.equals(id))).go();
}

/// Endereço com "https://" quando o usuário digitou só o domínio.
String? normalizeLink(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  final lower = t.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return t;
  return 'https://$t';
}

final wishesRepositoryProvider = Provider<WishesRepository>(
  (ref) => WishesRepository(ref.watch(databaseProvider)),
);

final wishesProvider = StreamProvider<WishesData>(
  (ref) => ref.watch(wishesRepositoryProvider).watch(),
);
