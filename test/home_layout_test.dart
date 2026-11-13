import 'package:aplicativo_all/core/navigation/module_prefs.dart';
import 'package:aplicativo_all/core/widgets/app_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaults = [
    'rotina',
    'tarefas',
    'notas',
    'compras',
    'academia',
    'biblia',
  ];

  group('tela inicial com fixados e recentes', () {
    test('fixados vêm primeiro e não se repetem nos recentes', () {
      final l = buildHomeLayout(
        history: const ['notas', 'tarefas', 'rotina'],
        pinned: const ['tarefas'],
        hidden: const {},
        defaults: defaults,
      );
      expect(l.pinned, ['tarefas']);
      expect(l.recents, ['notas', 'rotina']);
      expect(l.suggestions, isEmpty);
    });

    test('recentes continuam sendo seis mesmo com fixados', () {
      final history = [for (var i = 0; i < 10; i++) 'm$i'];
      final l = buildHomeLayout(
        history: history,
        pinned: const ['m0', 'm1'],
        hidden: const {},
        defaults: defaults,
      );
      expect(l.recents, ['m2', 'm3', 'm4', 'm5', 'm6', 'm7']);
    });

    test('ocultos não aparecem em nenhuma seção', () {
      final l = buildHomeLayout(
        history: const ['notas', 'tarefas'],
        pinned: const ['notas', 'rotina'],
        hidden: const {'notas'},
        defaults: defaults,
      );
      expect(l.pinned, ['rotina']);
      expect(l.recents, ['tarefas']);
    });

    test('desafixar faz o módulo voltar aos recentes pelo histórico', () {
      final l = buildHomeLayout(
        history: const ['notas', 'tarefas'],
        pinned: const [],
        hidden: const {},
        defaults: defaults,
      );
      expect(l.recents, ['notas', 'tarefas']);
    });

    test('sem histórico, sugestões sem repetir fixados nem ocultos', () {
      final l = buildHomeLayout(
        history: const [],
        pinned: const ['rotina'],
        hidden: const {'notas'},
        defaults: defaults,
      );
      expect(l.suggestions, ['tarefas', 'compras', 'academia', 'biblia']);
    });
  });

  test('lista gravada é lida com segurança', () {
    expect(decodeIdList(null), isEmpty);
    expect(decodeIdList('lixo'), isEmpty);
    expect(decodeIdList('["a","a","b",3]'), ['a', 'b']);
    expect(decodeIdList('["a","x"]', valid: {'a'}), ['a']);
  });

  test('cor salva é lida de volta', () {
    expect(parseAccent(null), isNull);
    expect(
      parseAccent('${const Color(0xFF6EA8FE).toARGB32()}'),
      const Color(0xFF6EA8FE),
    );
  });

  testWidgets('rodapé aparece abaixo da página com o texto exato', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WithAppFooter(child: Scaffold(body: Text('conteúdo'))),
      ),
    );
    expect(
      find.text('BrutAll - App desenvolvido por Lucas Brito Silva'),
      findsOneWidget,
    );
    final footer = tester.getTopLeft(find.byType(AppFooter));
    final content = tester.getBottomLeft(find.byType(Scaffold));
    expect(footer.dy, greaterThanOrEqualTo(content.dy));
  });
}
