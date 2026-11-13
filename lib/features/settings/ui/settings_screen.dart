import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_modules.dart';
import '../../../core/navigation/module_prefs.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

final _permissionsOverviewProvider =
    FutureProvider.autoDispose<
      ({PermissionState notifications, bool exact, PermissionState microphone})
    >((ref) async {
      final p = ref.watch(permissionServiceProvider);
      return (
        notifications: await p.notificationStatus(),
        exact: await p.exactAlarmsAllowed(),
        microphone: await p.microphoneStatus(),
      );
    });

/// Texto do aviso de armazenamento (exatamente como pedido).
const dataStorageWarning =
    'Atenção: os dados deste aplicativo são armazenados somente no '
    'dispositivo. Ao desinstalar o BrutAll, suas informações serão perdidas. '
    'O aplicativo não possui backup nem recuperação de dados.';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Ao voltar das configurações do Android, confere as permissões de novo.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(_permissionsOverviewProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(_permissionsOverviewProvider);
    final accent = ref.watch(accentColorProvider);
    final hidden = ref.watch(hiddenModulesProvider);
    final prefs = ref.read(modulePrefsProvider);
    final hiddenModules = [
      for (final m in appModules)
        if (hidden.contains(m.id)) m,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // ---- Aparência ----
          const SectionLabel(
            'Cor do aplicativo',
            padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Escolha a cor de destaque. As cores de aviso (erro, '
                    'sucesso) não mudam.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (name, color) in accentChoices)
                        _ColorDot(
                          name: name,
                          color: color,
                          selected: color.toARGB32() == accent.toARGB32(),
                          onTap: () => prefs.setAccent(
                            color.toARGB32() ==
                                    AppColors.defaultPrimary.toARGB32()
                                ? null
                                : color,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed:
                          accent.toARGB32() ==
                              AppColors.defaultPrimary.toARGB32()
                          ? null
                          : () => prefs.setAccent(null),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restaurar a cor original'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Módulos ----
          const SectionLabel(
            'Módulos',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Fixar e ocultar módulos'),
              subtitle: const Text(
                'Escolha o que fica fixado na tela inicial e o que não aparece',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ModulesManageScreen(),
                ),
              ),
            ),
          ),
          SectionLabel(
            'Funcionalidades ocultadas',
            padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
            trailing: hiddenModules.length > 1
                ? TextButton(
                    onPressed: prefs.showAll,
                    child: const Text('Restaurar todas'),
                  )
                : null,
          ),
          Card(
            child: hiddenModules.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Nenhuma funcionalidade oculta'),
                    subtitle: Text(
                      'Para ocultar, toque e segure um módulo no menu ou na '
                      'tela inicial.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      for (final m in hiddenModules)
                        ListTile(
                          leading: Icon(m.icon),
                          title: Text(m.title),
                          subtitle: const Text(
                            'Oculto · os dados continuam guardados',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          trailing: TextButton(
                            onPressed: () => prefs.show(m.id),
                            child: const Text('Restaurar'),
                          ),
                        ),
                    ],
                  ),
          ),

          // ---- Permissões ----
          const SectionLabel(
            'Permissões',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          ),
          Card(
            child: perms.when(
              loading: () =>
                  const Padding(padding: EdgeInsets.all(24), child: Loading()),
              error: (e, _) => ErrorText(e),
              data: (p) => Column(
                children: [
                  _PermissionTile(
                    icon: Icons.notifications_none,
                    title: 'Notificações',
                    granted: p.notifications == PermissionState.granted,
                    deniedText: 'Não permitidas: rotina e lembretes não avisam',
                    onFix: () async {
                      final s = ref.read(permissionServiceProvider);
                      final r = await s.requestNotifications();
                      if (r == PermissionState.blocked) await s.openSettings();
                      ref.invalidate(_permissionsOverviewProvider);
                    },
                  ),
                  _PermissionTile(
                    icon: Icons.alarm,
                    title: 'Alarmes exatos',
                    granted: p.exact,
                    deniedText:
                        'Desativados: os avisos podem atrasar alguns minutos',
                    onFix: () async {
                      final opened = await ref
                          .read(permissionServiceProvider)
                          .requestExactAlarms();
                      if (!opened && context.mounted) {
                        showMessage(
                          context,
                          'Este Android não tem a tela de alarmes exatos.',
                        );
                      }
                      ref.invalidate(_permissionsOverviewProvider);
                    },
                  ),
                  _PermissionTile(
                    icon: Icons.mic_none,
                    title: 'Microfone',
                    granted: p.microphone == PermissionState.granted,
                    deniedText: 'Pedido ao usar a ideia por voz',
                    onFix: () async {
                      final s = ref.read(permissionServiceProvider);
                      final r = await s.requestMicrophone();
                      if (r == PermissionState.blocked) await s.openSettings();
                      ref.invalidate(_permissionsOverviewProvider);
                    },
                  ),
                ],
              ),
            ),
          ),

          // ---- Armazenamento ----
          const SectionLabel(
            'Armazenamento de dados',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dataStorageWarning,
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // ---- Sobre ----
          const SectionLabel(
            'Sobre',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('BrutAll'),
              subtitle: Text(
                'Organização pessoal em um só lugar. Funciona sem internet e '
                'não envia seus dados para nenhum serviço.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cor $name',
      child: Tooltip(
        message: name,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.text : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.35
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.granted,
    required this.onFix,
    this.deniedText = 'Não permitidas',
  });

  final IconData icon;
  final String title;
  final bool granted;
  final String deniedText;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        granted ? 'Permitido' : deniedText,
        style: TextStyle(
          color: granted ? AppColors.textMuted : AppColors.danger,
          fontSize: 13,
        ),
      ),
      trailing: granted
          ? Icon(Icons.check, color: AppColors.primary)
          : TextButton(onPressed: onFix, child: const Text('Permitir')),
    );
  }
}

/// Todos os módulos, com as opções de fixar e de mostrar/ocultar.
class ModulesManageScreen extends ConsumerWidget {
  const ModulesManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenModulesProvider);
    final pinned = ref.watch(pinnedModulesProvider);
    final prefs = ref.read(modulePrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fixar e ocultar módulos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Fixados aparecem primeiro na tela inicial. Ocultos somem do '
              'menu e da tela inicial, sem perder os dados.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          for (final category in ModuleCategory.values) ...[
            SectionLabel(
              category.label,
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            ),
            Card(
              child: Column(
                children: [
                  for (final m in modulesOf(category))
                    ListTile(
                      leading: Icon(
                        m.icon,
                        color: hidden.contains(m.id)
                            ? AppColors.textFaint
                            : null,
                      ),
                      title: Text(
                        m.title,
                        style: hidden.contains(m.id)
                            ? const TextStyle(color: AppColors.textFaint)
                            : null,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: pinned.contains(m.id)
                                ? 'Desafixar'
                                : 'Fixar na tela inicial',
                            icon: Icon(
                              pinned.contains(m.id)
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              color: pinned.contains(m.id)
                                  ? AppColors.primary
                                  : null,
                            ),
                            onPressed: hidden.contains(m.id)
                                ? null
                                : () => pinned.contains(m.id)
                                      ? prefs.unpin(m.id)
                                      : prefs.pin(m.id),
                          ),
                          Switch(
                            value: !hidden.contains(m.id),
                            onChanged: (visible) =>
                                visible ? prefs.show(m.id) : prefs.hide(m.id),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
