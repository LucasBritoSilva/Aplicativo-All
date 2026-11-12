import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/shopping_section.dart';

class ShoppingRepository {
  ShoppingRepository(this._db);
  final AppDatabase _db;

  Stream<List<ShoppingItem>> watchAll() =>
      (_db.select(_db.shoppingItems)..orderBy([
            (t) => OrderingTerm.asc(t.bought),
            (t) => OrderingTerm.asc(t.name.collate(Collate.noCase)),
          ]))
          .watch();

  Future<void> add({
    required String name,
    String? quantity,
    required ShoppingSection section,
  }) => _db
      .into(_db.shoppingItems)
      .insert(
        ShoppingItemsCompanion.insert(
          name: name,
          quantity: Value(quantity),
          section: section,
        ),
      );

  Future<void> edit(
    int id, {
    required String name,
    String? quantity,
    required ShoppingSection section,
  }) => (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
    ShoppingItemsCompanion(
      name: Value(name),
      quantity: Value(quantity),
      section: Value(section),
    ),
  );

  Future<void> setBought(int id, bool bought) =>
      (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
        ShoppingItemsCompanion(bought: Value(bought)),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.shoppingItems)..where((t) => t.id.equals(id))).go();

  /// Remove da lista tudo o que já foi comprado.
  Future<int> clearBought() =>
      (_db.delete(_db.shoppingItems)..where((t) => t.bought.equals(true))).go();
}

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(ref.watch(databaseProvider)),
);

final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>(
  (ref) => ref.watch(shoppingRepositoryProvider).watchAll(),
);
