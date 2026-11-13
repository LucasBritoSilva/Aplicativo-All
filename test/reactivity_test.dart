import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:aplicativo_all/core/theme/app_theme.dart';
import 'package:aplicativo_all/features/notes/data/notes_repository.dart';
import 'package:aplicativo_all/features/notes/ui/note_editor_screen.dart';
import 'package:aplicativo_all/features/notes/ui/notes_screen.dart';
import 'package:aplicativo_all/features/routine/data/routine_repository.dart';
import 'package:aplicativo_all/features/tasks/data/tasks_repository.dart';
import 'package:aplicativo_all/features/tasks/domain/task_sorting.dart';
import 'package:aplicativo_all/features/tasks/ui/tasks_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> close(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<(AppDatabase, ProviderContainer)> open(
    WidgetTester tester,
    Widget home,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await settle(tester);
    return (db, container);
  }

  testWidgets('tarefa criada aparece na hora', (tester) async {
    final (_, c) = await open(tester, const TasksScreen());
    await tester.runAsync(
      () => c
          .read(tasksRepositoryProvider)
          .save(title: 'Comprar pão', priority: TaskPriority.alta),
    );
    await settle(tester);
    expect(find.text('Comprar pão'), findsOneWidget);
    await close(tester, c);
  });

  testWidgets('tarefa alterada com outra tela por cima aparece ao voltar', (
    tester,
  ) async {
    final (_, c) = await open(tester, const TasksScreen());
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('outra')),
      ),
    );
    await settle(tester);
    await tester.runAsync(
      () => c
          .read(tasksRepositoryProvider)
          .save(title: 'Pagar conta', priority: TaskPriority.media),
    );
    await settle(tester);
    nav.pop();
    await settle(tester);
    expect(find.text('Pagar conta'), findsOneWidget);
    await close(tester, c);
  });

  testWidgets('nota salva com o editor por cima aparece ao voltar', (
    tester,
  ) async {
    final (_, c) = await open(tester, const NotesScreen());
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('editor')),
      ),
    );
    await settle(tester);
    await tester.runAsync(
      () => c.read(notesRepositoryProvider).save(body: 'Ideia nova'),
    );
    await settle(tester);
    nav.pop();
    await settle(tester);
    expect(find.text('Ideia nova'), findsOneWidget);
    await close(tester, c);
  });

  testWidgets('tarefas atualizam mesmo com a rotina observada antes', (
    tester,
  ) async {
    // Cenário real: a rotina abre o primeiro stream combinado do app.
    final (_, c) = await open(tester, const TasksScreen());
    final routineSub = c.listen(routineDayProvider(20000), (_, _) {});
    await settle(tester);
    await tester.runAsync(
      () => c
          .read(tasksRepositoryProvider)
          .save(title: 'Depois da rotina', priority: TaskPriority.baixa),
    );
    await settle(tester);
    expect(find.text('Depois da rotina'), findsOneWidget);
    routineSub.close();
    await close(tester, c);
  });

  test('cada conjunto de tabelas tem seu próprio stream', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final routine = db.watchTables({db.routineOccurrences}, () async => 'r');
    final tasks = db.watchTables({
      db.tasks,
    }, () async => (await db.select(db.tasks).get()).length);
    final seen = <int>[];
    final s1 = routine.listen((_) {});
    final s2 = tasks.listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db
        .into(db.tasks)
        .insert(TasksCompanion.insert(title: 'x', priority: TaskPriority.alta));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last, 1);
    await s1.cancel();
    await s2.cancel();
    await db.close();
  });

  testWidgets('nota escrita no editor aparece ao voltar', (tester) async {
    final (_, c) = await open(tester, const NotesScreen());
    await tester.tap(find.byTooltip('Nova anotação'));
    await settle(tester);
    expect(find.byType(NoteEditorScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Texto do editor');
    await tester.tap(find.byTooltip('Salvar'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Texto do editor'), findsOneWidget);
    await close(tester, c);
  });
}
