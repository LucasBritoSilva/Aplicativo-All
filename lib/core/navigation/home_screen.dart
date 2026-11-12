import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/today_provider.dart';
import '../widgets/common.dart';
import 'app_drawer.dart';
import 'app_modules.dart';
import 'recent_modules.dart';

/// Tela inicial: grade com os 6 módulos abertos mais recentemente.
///
/// Abrir esta tela não conta como acesso e não muda a ordem. Enquanto não
/// houver seis acessos, as posições vazias mostram sugestões, com
/// aparência diferente dos recentes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final recents = ref.watch(recentModulesProvider).value ?? const <String>[];
    final suggestions = suggestedModules(recents, defaultModuleSuggestions);

    final tiles = <Widget>[
      for (final id in recents)
        if (moduleById(id) case final module?)
          _ModuleTile(module: module, suggestion: false),
      for (final id in suggestions)
        if (moduleById(id) case final module?)
          _ModuleTile(module: module, suggestion: true),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('All')),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              '${weekdayLong(today)}, ${formatLongDate(today)}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          SectionLabel(
            recents.isEmpty ? 'Sugestões para começar' : 'Recentes',
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: tiles,
          ),
          const SizedBox(height: 20),
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

class _ModuleTile extends ConsumerWidget {
  const _ModuleTile({required this.module, required this.suggestion});

  final AppModule module;
  final bool suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    child: suggestion
                        ? const Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Pill('Sugestão'),
                            ),
                          )
                        : const SizedBox.shrink(),
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
