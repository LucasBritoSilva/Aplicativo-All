import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/drive_backup_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../reminders/data/reminders_repository.dart';
import '../../routine/data/routine_sync.dart';

final _permissionsOverviewProvider = FutureProvider.autoDispose<
  ({PermissionState notifications, bool exact, PermissionState microphone})
>((ref) async {
  final p = ref.watch(permissionServiceProvider);
  return (
    notifications: await p.notificationStatus(),
    exact: await p.exactAlarmsAllowed(),
    microphone: await p.microphoneStatus(),
  );
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppLifecycleListener _lifecycle;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(_permissionsOverviewProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
    } on BackupException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Algo deu errado: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Não deu certo'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _when(DateTime d) => '${formatDate(d)} às ${formatTime(d)}';

  Future<void> _backup() => _run('Enviando backup...', () async {
    final service = ref.read(driveBackupServiceProvider);
    final existing = await service.findBackup();
    if (existing != null && mounted) {
      final when = existing.modifiedTime == null
          ? ''
          : ' (de ${_when(existing.modifiedTime!)})';
      final ok = await confirm(
        context,
        title: 'Substituir backup?',
        message:
            'Já existe um backup no seu Google Drive$when. Ele será '
            'substituído pelos dados atuais deste celular.',
        confirmLabel: 'Substituir',
      );
      if (!ok) return;
    }
    final at = await service.backup();
    if (mounted) showMessage(context, 'Backup feito em ${_when(at)}.');
  });

  Future<void> _restore() => _run('Buscando backup...', () async {
    final service = ref.read(driveBackupServiceProvider);
    final snapshot = await service.download();
    if (!mounted) return;
    final ok = await confirm(
      context,
      title: 'Restaurar backup?',
      message:
          'Backup de ${_when(snapshot.exportedAt)} com '
          '${snapshot.totalRows} registros.\n\n'
          'TODOS os dados atuais deste celular serão apagados e trocados '
          'pelos dados do backup. Isso não pode ser desfeito.',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = 'Restaurando...');
    await service.restore(snapshot);
    // Lembretes e rotina restaurados precisam ser agendados de novo.
    await ref.read(reminderSchedulerProvider).resync();
    await ref.read(routineSyncProvider).run();
    if (mounted) showMessage(context, 'Dados restaurados.');
  });

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(backupConfigProvider);
    final perms = ref.watch(_permissionsOverviewProvider);
    final configured = config.maybeWhen(
      data: (c) => c.isConfigured,
      orElse: () => false,
    );
    final busy = _busy != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionLabel(
            'Backup no Google Drive',
            padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Guarda uma cópia dos dados na pasta privada do app no '
                    'seu Google Drive. Nada é enviado sem você tocar em um '
                    'dos botões abaixo. O Cofre não entra no backup: ele só '
                    'pode ser lido neste aparelho.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  if (!configured && !config.isLoading) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Backup no Google Drive não configurado nesta versão '
                        'do app: ele depende de um cadastro no Google Cloud '
                        'feito por quem compila o app (veja '
                        'docs/BACKUP_GOOGLE_DRIVE.md no repositório). Todo o '
                        'resto funciona sem ele.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (busy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _busy!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: configured && !busy ? _backup : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Fazer backup'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: configured && !busy ? _restore : null,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Restaurar'),
                  ),
                ],
              ),
            ),
          ),
          const SectionLabel(
            'Permissões',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          ),
          Card(
            child: perms.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Loading(),
              ),
              error: (e, _) => ErrorText(e),
              data: (p) => Column(
                children: [
                  _PermissionTile(
                    icon: Icons.notifications_none,
                    title: 'Notificações',
                    granted: p.notifications == PermissionState.granted,
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
                    deniedText: 'Desativados: lembretes podem atrasar',
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
          const SectionLabel('Sobre', padding: EdgeInsets.fromLTRB(4, 24, 4, 8)),
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('All 2.0.0'),
              subtitle: Text(
                'Todos os dados ficam neste celular. A internet só é usada '
                'pelo backup no Google Drive, quando você pede, e pelos '
                'links que você mesmo abre.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
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
          ? const Icon(Icons.check, color: AppColors.primary)
          : TextButton(onPressed: onFix, child: const Text('Permitir')),
    );
  }
}
