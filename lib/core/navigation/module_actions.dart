import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/common.dart';
import 'app_modules.dart';
import 'module_prefs.dart';

/// Opções de um módulo: fixar/desafixar na tela inicial e ocultar.
/// Abre com um toque longo no atalho ou no item do menu.
Future<void> showModuleOptions(
  BuildContext context,
  WidgetRef ref,
  AppModule module,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final pinned = ref.watch(pinnedModulesProvider).contains(module.id);
        final prefs = ref.read(modulePrefsProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(module.icon),
              title: Text(
                module.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(
                pinned ? 'Desafixar da tela inicial' : 'Fixar na tela inicial',
              ),
              onTap: () async {
                Navigator.pop(sheet);
                if (pinned) {
                  await prefs.unpin(module.id);
                } else {
                  await prefs.pin(module.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Ocultar este módulo'),
              subtitle: const Text(
                'Some do menu e da tela inicial. Os dados ficam guardados e '
                'ele pode ser restaurado em Configurações.',
              ),
              onTap: () async {
                Navigator.pop(sheet);
                await prefs.hide(module.id);
                if (context.mounted) {
                  showMessage(
                    context,
                    '"${module.title}" foi ocultado. Restaure em '
                    'Configurações → Funcionalidades ocultadas.',
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    ),
  );
}
