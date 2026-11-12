import 'package:app_pessoal/core/backup/backup_codec.dart';
import 'package:app_pessoal/core/backup/database_snapshot.dart';
import 'package:app_pessoal/core/database/app_database.dart';
import 'package:app_pessoal/features/shopping/domain/shopping_section.dart';
import 'package:app_pessoal/features/tasks/domain/task_sorting.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase source;
  late AppDatabase target;

  // Os dois bancos são independentes (cada um em memória), então o aviso
  // do drift sobre "várias instâncias" não se aplica aqui.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    source = _memoryDb();
    target = _memoryDb();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<void> fill(AppDatabase db) async {
    await db
        .into(db.shoppingItems)
        .insert(
          ShoppingItemsCompanion.insert(
            name: 'Tomate',
            section: ShoppingSection.hortifruti,
            quantity: const Value('1 kg'),
          ),
        );
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: 'Pagar conta',
            priority: TaskPriority.alta,
            dueDate: Value(DateTime(2026, 11, 20)),
          ),
        );
    final habitId = await db
        .into(db.habits)
        .insert(HabitsCompanion.insert(name: 'Correr', weeklyTarget: 3));
    await db
        .into(db.habitChecks)
        .insert(
          HabitChecksCompanion.insert(
            habitId: habitId,
            day: DateTime(2026, 11, 10),
          ),
        );
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            title: 'Ler livros',
            targetValue: 20,
            currentValue: const Value(2.5),
          ),
        );
    await db
        .into(db.notes)
        .insert(NotesCompanion.insert(body: 'Ideia', fromVoice: const Value(true)));
  }

  test('exportar e restaurar reproduz os dados e substitui os antigos', () async {
    await fill(source);
    // O destino tem dados que devem sumir após a restauração.
    await target
        .into(target.notes)
        .insert(NotesCompanion.insert(body: 'vai sumir'));

    final json = (await DatabaseSnapshot(source).export()).encode();
    await DatabaseSnapshot(target).restore(BackupSnapshot.decode(json));

    final notes = await target.select(target.notes).get();
    expect(notes.map((n) => n.body), ['Ideia']);
    expect(notes.single.fromVoice, isTrue);

    final item = await target.select(target.shoppingItems).getSingle();
    expect(item.name, 'Tomate');
    expect(item.section, ShoppingSection.hortifruti);
    expect(item.quantity, '1 kg');

    final task = await target.select(target.tasks).getSingle();
    expect(task.priority, TaskPriority.alta);
    expect(task.dueDate, DateTime(2026, 11, 20));

    final checks = await target.select(target.habitChecks).get();
    expect(checks.single.day, DateTime(2026, 11, 10));

    final goal = await target.select(target.goals).getSingle();
    expect(goal.currentValue, 2.5);
    expect(goal.targetValue, 20);
  });

  test('backup inválido não apaga nada do celular', () async {
    await fill(target);
    final bad = BackupSnapshot(
      schemaVersion: 1,
      exportedAt: DateTime(2026, 11, 11),
      tables: {
        'notes': [
          {'id': 1, 'coluna_que_nao_existe': 'x'},
        ],
      },
    );
    await expectLater(
      DatabaseSnapshot(target).restore(bad),
      throwsFormatException,
    );
    expect(await target.select(target.notes).get(), hasLength(1));
    expect(await target.select(target.tasks).get(), hasLength(1));
  });

  test('erro no meio da restauração desfaz tudo (transação)', () async {
    await fill(target);
    final broken = BackupSnapshot(
      schemaVersion: 1,
      exportedAt: DateTime(2026, 11, 11),
      tables: {
        // Marcação apontando para um hábito que não existe: viola a chave
        // estrangeira e a transação inteira é desfeita.
        'habit_checks': [
          {'id': 1, 'habit_id': 999, 'day': 1700000000},
        ],
      },
    );
    await expectLater(DatabaseSnapshot(target).restore(broken), throwsA(anything));
    expect(await target.select(target.notes).get(), hasLength(1));
    expect(await target.select(target.habits).get(), hasLength(1));
  });
}
