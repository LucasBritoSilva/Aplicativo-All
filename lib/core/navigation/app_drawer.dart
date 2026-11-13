import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/ui/settings_screen.dart';
import '../theme/app_theme.dart';
import 'app_modules.dart';
import 'module_actions.dart';
import 'module_prefs.dart';

/// Menu lateral: as seis categorias, cada uma abrindo seus módulos.
/// Módulos ocultados não aparecem; categorias vazias também não.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenModulesProvider);
    final pinned = ref.watch(pinnedModulesProvider);
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/brand/brutall.png',
                      width: 52,
                      height: 52,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BrutAll',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tudo organizado em um só lugar',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Início'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(height: 1),
            for (final category in ModuleCategory.values)
              if (modulesOf(category).where((m) => !hidden.contains(m.id))
                  case final visible when visible.isNotEmpty)
                ExpansionTile(
                  leading: Icon(category.icon),
                  title: Text(category.label),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final module in visible)
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 32,
                          right: 16,
                        ),
                        leading: Icon(module.icon, size: 22),
                        title: Text(module.title),
                        trailing: pinned.contains(module.id)
                            ? Icon(
                                Icons.push_pin,
                                size: 16,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          openModule(navigator, ref, module);
                        },
                        onLongPress: () =>
                            showModuleOptions(context, ref, module),
                      ),
                  ],
                ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configurações'),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                'Toque e segure um módulo para fixar ou ocultar.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
