import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/today_provider.dart';
import '../widgets/common.dart';
import 'app_drawer.dart';
import 'app_modules.dart';
import 'module_actions.dart';
import 'module_prefs.dart';
import 'recent_modules.dart';

/// Tela inicial: módulos fixados e os 6 módulos usados mais recentemente.
///
/// Abrir esta tela não conta como acesso e não muda a ordem. Enquanto não
/// houver histórico, os recentes mostram sugestões, com aparência
/// diferente. Toque longo num atalho para fixar, desafixar ou ocultar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final layout = buildHomeLayout(
      history: ref.watch(recentModulesProvider).value ?? const <String>[],
      pinned: ref.watch(pinnedModulesProvider),
      hidden: ref.watch(hiddenModulesProvider),
      defaults: defaultModuleSuggestions,
    );

    Widget grid(List<Widget> tiles) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: tiles,
    );

    List<Widget> tiles(List<String> ids, _TileStyle style) => [
      for (final id in ids)
        if (moduleById(id) case final module?)
          _ModuleTile(module: module, style: style),
    ];

    final recentTiles = [
      ...tiles(layout.recents, _TileStyle.recent),
      ...tiles(layout.suggestions, _TileStyle.suggestion),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('BrutAll')),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              '${weekdayLong(today)}, ${formatLongDate(today)}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (layout.pinned.isNotEmpty) ...[
            const SectionLabel(
              'Fixados',
              padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
            ),
            grid(tiles(layout.pinned, _TileStyle.pinned)),
          ],
          SectionLabel(
            layout.recents.isEmpty && layout.suggestions.isNotEmpty
                ? 'Sugestões para começar'
                : 'Recentes',
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          if (recentTiles.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'Os módulos que você abrir aparecem aqui.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            grid(recentTiles),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Toque e segure um atalho para fixar, desafixar ou ocultar.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) => OutlinedButton.icon(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
              label: const Text('Ver todos os módulos'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TileStyle { pinned, recent, suggestion }

class _ModuleTile extends ConsumerWidget {
  const _ModuleTile({required this.module, required this.style});

  final AppModule module;
  final _TileStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = style == _TileStyle.suggestion;
    final color = suggestion ? AppColors.textMuted : AppColors.primary;
    return Material(
      color: suggestion ? Colors.transparent : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: suggestion ? AppColors.outline : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openModule(Navigator.of(context), ref, module),
        onLongPress: () => showModuleOptions(context, ref, module),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(module.icon, color: color, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: switch (style) {
                        _TileStyle.suggestion => const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Pill('Sugestão'),
                        ),
                        _TileStyle.pinned => Icon(
                          Icons.push_pin,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        _TileStyle.recent => const SizedBox.shrink(),
                      },
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                module.tileTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: suggestion ? AppColors.textMuted : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
