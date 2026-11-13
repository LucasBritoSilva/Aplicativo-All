import 'package:aplicativo_all/core/database/app_database.dart';
import 'package:aplicativo_all/core/navigation/app_modules.dart';
import 'package:aplicativo_all/core/navigation/home_screen.dart';
import 'package:aplicativo_all/core/theme/app_theme.dart';
import 'package:aplicativo_all/features/settings/ui/settings_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre cada tela num app de teste com banco vazio em memória e confere
/// que nada quebra (estado vazio, carregamento e layout em tela pequena).
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> open(WidgetTester tester, WidgetBuilder builder) async {
    tester.view.physicalSize = const Size(360 * 3, 690 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: builder),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    // O banco em memória é descartado com o teste; fechá-lo aqui, dentro
    // do relógio falso do teste, pode travar.
    addTearDown(() => db.close());
  }

  testWidgets('tela inicial abre com sugestões e o menu', (tester) async {
    await open(tester, (_) => const HomeScreen());
  });

  testWidgets('configurações abrem sem erro', (tester) async {
    await open(tester, (_) => const SettingsScreen());
  });

  testWidgets('fixar e ocultar módulos abre sem erro', (tester) async {
    await open(tester, (_) => const ModulesManageScreen());
  });

  for (final module in appModules) {
    testWidgets('módulo ${module.title} abre sem erro', (tester) async {
      await open(tester, module.builder);
    });
  }
}
