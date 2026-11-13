import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:aplicativo_all/features/notes/data/notes_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late NotesRepository repo;
  late List<String> deleted;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    deleted = [];
    repo = NotesRepository(db, (paths) async => deleted.addAll(paths));
  });
  tearDown(() => db.close());

  test('nota guarda imagens na ordem escolhida', () async {
    final id = await repo.save(body: 'Viagem');
    await repo.setImages(id, ['/a.jpg', '/b.jpg']);
    final imgs = await repo.imagesOf(id);
    expect(imgs.map((i) => i.path), ['/a.jpg', '/b.jpg']);
    expect(deleted, isEmpty);
  });

  test('remover uma imagem apaga só o arquivo dela', () async {
    final id = await repo.save(body: 'Viagem');
    await repo.setImages(id, ['/a.jpg', '/b.jpg', '/c.jpg']);
    await repo.setImages(id, ['/c.jpg', '/a.jpg']);
    expect((await repo.imagesOf(id)).map((i) => i.path), ['/c.jpg', '/a.jpg']);
    expect(deleted, ['/b.jpg']);
  });

  test('excluir a nota apaga as imagens dela', () async {
    final id = await repo.save(body: 'Recibo');
    final other = await repo.save(body: 'Outra');
    await repo.setImages(id, ['/r1.jpg', '/r2.jpg']);
    await repo.setImages(other, ['/o.jpg']);
    await repo.delete(id);
    expect(deleted, unorderedEquals(['/r1.jpg', '/r2.jpg']));
    expect(await repo.imagesOf(id), isEmpty);
    expect((await repo.imagesOf(other)).single.path, '/o.jpg');
  });

  test('nota só com imagem (sem texto) é válida', () async {
    final id = await repo.save(body: '');
    await repo.setImages(id, ['/foto.jpg']);
    final grouped = await repo.watchImages().first;
    expect(grouped[id]!.single.path, '/foto.jpg');
  });
}
