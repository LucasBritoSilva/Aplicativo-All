import 'package:aplicativo_all/core/navigation/app_modules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('21 módulos confirmados em 6 categorias', () {
    expect(ModuleCategory.values, hasLength(6));
    final confirmed = appModules.where((m) => m.confirmed).toList();
    expect(confirmed, hasLength(21));
    int count(ModuleCategory c) =>
        confirmed.where((m) => m.category == c).length;
    expect(count(ModuleCategory.organizacao), 6);
    expect(count(ModuleCategory.anotacoes), 3);
    expect(count(ModuleCategory.vidaPessoal), 4);
    expect(count(ModuleCategory.faculdade), 2);
    expect(count(ModuleCategory.saude), 3);
    expect(count(ModuleCategory.ferramentas), 3);
  });

  test('módulos antigos preservados: Lembretes, Hábitos e Metas', () {
    final legacy = appModules.where((m) => !m.confirmed).map((m) => m.id);
    expect(legacy, containsAll(['lembretes', 'habitos', 'metas']));
  });

  test('ids únicos e módulos recusados ausentes', () {
    final ids = appModules.map((m) => m.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    final titles = appModules.map((m) => m.title.toLowerCase()).join(' ');
    expect(titles, isNot(contains('compras futuras')));
    expect(titles, isNot(contains('encomenda')));
    expect(titles, isNot(contains('calendário')));
  });

  test('sugestões iniciais existem no menu', () {
    for (final id in defaultModuleSuggestions) {
      expect(moduleById(id), isNotNull, reason: id);
    }
    expect(defaultModuleSuggestions, hasLength(6));
  });
}
