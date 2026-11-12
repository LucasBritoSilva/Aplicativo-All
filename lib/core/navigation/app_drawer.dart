import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/ui/settings_screen.dart';
import '../theme/app_theme.dart';
import 'app_modules.dart';

/// Menu lateral: as seis categorias, cada uma abrindo seus módulos.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tudo organizado em um só lugar',
                    style: TextStyle(color: AppColors.textMuted),
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
              ExpansionTile(
                leading: Icon(category.icon),
                title: Text(category.label),
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final module in modulesOf(category))
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      leading: Icon(module.icon, size: 22),
                      title: Text(module.title),
                      onTap: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        openModule(navigator, ref, module);
                      },
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
          ],
        ),
      ),
    );
  }
}
