import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_repository.dart';
import '../theme/app_theme.dart';

/// Lista de ids gravada como JSON, descartando o que for inválido.
List<String> decodeIdList(String? raw, {Set<String>? valid}) {
  if (raw == null || raw.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final out = <String>[];
  for (final item in decoded) {
    if (item is String &&
        (valid == null || valid.contains(item)) &&
        !out.contains(item)) {
      out.add(item);
    }
  }
  return out;
}

/// O que a tela inicial mostra em cada seção.
class HomeLayout {
  const HomeLayout({
    required this.pinned,
    required this.recents,
    required this.suggestions,
  });

  final List<String> pinned;
  final List<String> recents;
  final List<String> suggestions;
}

/// Monta a tela inicial: fixados primeiro; depois os [maxRecents] módulos
/// usados mais recentemente que não estão fixados; e, enquanto não houver
/// histórico suficiente, sugestões para completar os recentes.
///
/// Módulos ocultados nunca aparecem, e nenhum módulo aparece duas vezes.
HomeLayout buildHomeLayout({
  required List<String> history,
  required List<String> pinned,
  required Set<String> hidden,
  required List<String> defaults,
  int maxRecents = 6,
}) {
  final shownPinned = [
    for (final id in pinned)
      if (!hidden.contains(id)) id,
  ];
  final used = {...shownPinned};
  final recents = <String>[];
  for (final id in history) {
    if (recents.length == maxRecents) break;
    if (hidden.contains(id) || used.contains(id)) continue;
    recents.add(id);
    used.add(id);
  }
  final suggestions = <String>[];
  if (history.isEmpty) {
    for (final id in defaults) {
      if (recents.length + suggestions.length == maxRecents) break;
      if (hidden.contains(id) || used.contains(id)) continue;
      suggestions.add(id);
      used.add(id);
    }
  }
  return HomeLayout(
    pinned: shownPinned,
    recents: recents,
    suggestions: suggestions,
  );
}

/// Preferências de módulos: ocultos, fixados e a cor do app.
class ModulePrefsRepository {
  ModulePrefsRepository(this._settings);
  final SettingsRepository _settings;

  Future<List<String>> _read(String key) async =>
      decodeIdList(await _settings.read(key));

  Future<void> _write(String key, List<String> ids) =>
      _settings.write(key, jsonEncode(ids));

  /// Oculta o módulo (os dados continuam guardados) e tira dos fixados.
  Future<void> hide(String id) async {
    final hidden = await _read(SettingKeys.hiddenModules);
    if (!hidden.contains(id)) {
      await _write(SettingKeys.hiddenModules, [...hidden, id]);
    }
    final pinned = await _read(SettingKeys.pinnedModules);
    if (pinned.contains(id)) {
      await _write(
        SettingKeys.pinnedModules,
        pinned.where((p) => p != id).toList(),
      );
    }
  }

  Future<void> show(String id) async {
    final hidden = await _read(SettingKeys.hiddenModules);
    await _write(
      SettingKeys.hiddenModules,
      hidden.where((h) => h != id).toList(),
    );
  }

  Future<void> showAll() => _write(SettingKeys.hiddenModules, const []);

  Future<void> pin(String id) async {
    final pinned = await _read(SettingKeys.pinnedModules);
    if (!pinned.contains(id)) {
      await _write(SettingKeys.pinnedModules, [...pinned, id]);
    }
  }

  Future<void> unpin(String id) async {
    final pinned = await _read(SettingKeys.pinnedModules);
    await _write(
      SettingKeys.pinnedModules,
      pinned.where((p) => p != id).toList(),
    );
  }

  Future<void> setAccent(Color? color) => color == null
      ? _settings.remove(SettingKeys.accentColor)
      : _settings.write(SettingKeys.accentColor, '${color.toARGB32()}');
}

final modulePrefsProvider = Provider<ModulePrefsRepository>(
  (ref) => ModulePrefsRepository(ref.watch(settingsRepositoryProvider)),
);

/// Módulos ocultados pelo usuário.
final hiddenModulesProvider = Provider<Set<String>>(
  (ref) =>
      decodeIdList(ref.watch(settingProvider(SettingKeys.hiddenModules)).value)
          .toSet(),
);

/// Módulos fixados na tela inicial, na ordem em que foram fixados.
final pinnedModulesProvider = Provider<List<String>>(
  (ref) =>
      decodeIdList(ref.watch(settingProvider(SettingKeys.pinnedModules)).value),
);

/// Cor de destaque escolhida (nula = roxo original).
Color? parseAccent(String? raw) {
  final v = int.tryParse(raw ?? '');
  return v == null ? null : Color(v);
}

final accentColorProvider = Provider<Color>(
  (ref) =>
      parseAccent(ref.watch(settingProvider(SettingKeys.accentColor)).value) ??
      AppColors.defaultPrimary,
);
