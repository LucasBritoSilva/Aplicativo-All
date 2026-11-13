import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_repository.dart';
import 'app_modules.dart';

/// Quantos atalhos recentes a tela inicial mostra.
const maxRecentModules = 6;

/// Quantos acessos ficam guardados no histórico. É mais que os seis da tela
/// para que, com módulos fixados ou ocultos, ainda sobrem seis recentes.
const maxStoredRecents = 30;

/// Nova lista de recentes depois de abrir o módulo [id].
///
/// O módulo aberto vai para o primeiro lugar, sem duplicar. Se a lista
/// passar de [max], o mais antigo sai.
List<String> pushRecentModule(
  List<String> current,
  String id, {
  int max = maxRecentModules,
}) {
  final next = [id, ...current.where((m) => m != id)];
  return next.length > max ? next.sublist(0, max) : next;
}

/// Lê a lista gravada, descartando o que não for um módulo conhecido.
List<String> parseRecentModules(
  String? stored,
  Set<String> validIds, {
  int max = maxRecentModules,
}) {
  if (stored == null || stored.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final out = <String>[];
  for (final item in decoded) {
    if (item is String && validIds.contains(item) && !out.contains(item)) {
      out.add(item);
      if (out.length == max) break;
    }
  }
  return out;
}

/// Atalhos sugeridos para completar a grade enquanto não há seis acessos.
/// Nunca repetem um módulo que já está nos recentes.
List<String> suggestedModules(
  List<String> recents,
  List<String> defaults, {
  int max = maxRecentModules,
}) {
  final missing = max - recents.length;
  if (missing <= 0) return const [];
  return defaults.where((d) => !recents.contains(d)).take(missing).toList();
}

/// Histórico dos módulos abertos, do mais recente para o mais antigo.
///
/// Fica gravado no banco, então continua igual depois de fechar o app.
/// Abrir a tela inicial ou o menu não altera a lista: só [registerAccess].
class RecentModulesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final stored = await ref
        .watch(settingsRepositoryProvider)
        .read(SettingKeys.recentModules);
    return parseRecentModules(stored, {
      for (final m in appModules) m.id,
    }, max: maxStoredRecents);
  }

  Future<void> registerAccess(String id) async {
    final current = state.value ?? await future;
    final next = pushRecentModule(current, id, max: maxStoredRecents);
    state = AsyncData(next);
    await ref
        .read(settingsRepositoryProvider)
        .write(SettingKeys.recentModules, jsonEncode(next));
  }
}

final recentModulesProvider =
    AsyncNotifierProvider<RecentModulesNotifier, List<String>>(
      RecentModulesNotifier.new,
    );
