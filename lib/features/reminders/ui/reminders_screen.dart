import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../data/reminders_repository.dart';

/// Situação das permissões que os lembretes usam.
final reminderPermissionsProvider =
    FutureProvider.autoDispose<({bool notifications, bool exact})>((ref) async {
      final perms = ref.watch(permissionServiceProvider);
      final notif = await perms.notificationStatus();
      final exact = await perms.exactAlarmsAllowed();
      return (
        notifications: notif == PermissionState.granted,
        exact: exact,
      );
    });

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Ao voltar das configurações do Android, confere as permissões de novo.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(reminderPermissionsProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider);
    final perms = ref.watch(reminderPermissionsProvider);
    final today = ref.watch(todayProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo lembrete',
        onPressed: () => openReminderForm(context),
        child: const Icon(Icons.add_alert_outlined),
      ),
      body: reminders.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          final upcoming = list.where((r) => r.scheduledAt.isAfter(now));
          final past = list
              .where((r) => !r.scheduledAt.isAfter(now))
              .toList()
              .reversed;
          final banners = perms.maybeWhen(
            data: (p) => [
              if (!p.notifications)
                _Banner(
                  icon: Icons.notifications_off_outlined,
                  text:
                      'As notificações estão desativadas. Sem elas, os '
                      'lembretes não aparecem.',
                  action: 'Permitir',
                  onTap: _askNotifications,
                ),
              if (!p.exact)
                _Banner(
                  icon: Icons.timer_off_outlined,
                  text:
                      'Alarmes exatos desativados: os lembretes podem atrasar '
                      'alguns minutos.',
                  action: 'Ativar',
                  onTap: _askExact,
                ),
            ],
            orElse: () => const <Widget>[],
          );

          if (list.isEmpty) {
            return Column(
              children: [
                ...banners,
                const Expanded(
                  child: EmptyState(
                    icon: Icons.notifications_none,
                    title: 'Nenhum lembrete',
                    message:
                        'Toque no botão para criar um lembrete com data e hora.',
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              ...banners,
              if (upcoming.isNotEmpty) ...[
                const SectionLabel(
                  'Próximos',
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final r in upcoming)
                        _ReminderTile(reminder: r, today: today),
                    ],
                  ),
                ),
              ],
              if (past.isNotEmpty) ...[
                SectionLabel(
                  'Já passaram',
                  padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
                  trailing: TextButton(
                    onPressed: _clearPast,
                    child: const Text('Limpar'),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final r in past)
                        _ReminderTile(reminder: r, today: today, past: true),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _askNotifications() async {
    final perms = ref.read(permissionServiceProvider);
    final result = await perms.requestNotifications();
    if (result == PermissionState.blocked) await perms.openSettings();
    ref.invalidate(reminderPermissionsProvider);
  }

  /// Abre a tela "Alarmes e lembretes". Ao voltar, o app confere a
  /// permissão de novo e reagenda tudo no modo certo (ver App).
  Future<void> _askExact() async {
    final opened = await ref.read(permissionServiceProvider).requestExactAlarms();
    if (!opened && mounted) {
      showMessage(
        context,
        'Este Android não tem a tela de alarmes exatos. Os lembretes podem '
        'atrasar alguns minutos.',
      );
    }
    ref.invalidate(reminderPermissionsProvider);
  }

  Future<void> _clearPast() async {
    final ok = await confirm(
      context,
      title: 'Limpar lembretes antigos',
      message: 'Excluir os lembretes cujo horário já passou?',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await ref.read(reminderSchedulerProvider).clearPast();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.today,
    this.past = false,
  });

  final Reminder reminder;
  final DateTime today;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final when = reminder.scheduledAt;
    return ListTile(
      onTap: () => openReminderForm(context, reminder: reminder),
      leading: Icon(
        past ? Icons.notifications_none : Icons.notifications_active_outlined,
        color: past ? AppColors.textFaint : AppColors.primary,
      ),
      title: Text(
        reminder.title,
        style: past ? const TextStyle(color: AppColors.textMuted) : null,
      ),
      subtitle: Text(
        '${friendlyDay(when, today)} às ${formatTime(when)}'
        '${reminder.notes == null ? '' : '\n${reminder.notes}'}',
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

/// Abre o formulário de lembrete.
void openReminderForm(BuildContext context, {Reminder? reminder}) {
  showFormSheet<void>(
    context,
    title: reminder == null ? 'Novo lembrete' : 'Editar lembrete',
    builder: (_) => _ReminderForm(reminder: reminder),
  );
}

class _ReminderForm extends ConsumerStatefulWidget {
  const _ReminderForm({this.reminder});
  final Reminder? reminder;

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  late final _title = TextEditingController(text: widget.reminder?.title);
  late final _notes = TextEditingController(text: widget.reminder?.notes);
  late DateTime _day;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.reminder?.scheduledAt ??
        DateTime.now().add(const Duration(hours: 1));
    _day = dateOnly(initial);
    _time = widget.reminder == null
        ? TimeOfDay(hour: initial.hour, minute: 0)
        : TimeOfDay.fromDateTime(initial);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _when =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Digite o lembrete.');
      return;
    }
    if (!_when.isAfter(DateTime.now())) {
      showMessage(context, 'Escolha um horário no futuro.');
      return;
    }

    // POST_NOTIFICATIONS: pedida na hora em que o recurso é usado.
    final perms = ref.read(permissionServiceProvider);
    if (await perms.notificationStatus() != PermissionState.granted) {
      await perms.requestNotifications();
    }

    final notes = _notes.text.trim();
    final outcome = await ref
        .read(reminderSchedulerProvider)
        .save(
          id: widget.reminder?.id,
          title: title,
          notes: notes.isEmpty ? null : notes,
          scheduledAt: _when,
        );
    ref.invalidate(reminderPermissionsProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final msg = switch (outcome) {
      ScheduleOutcome.exact => 'Lembrete agendado.',
      ScheduleOutcome.inexact =>
        'Lembrete agendado, mas os alarmes exatos estão desativados: '
            'ele pode atrasar alguns minutos.',
      ScheduleOutcome.past => 'Esse horário já passou.',
      ScheduleOutcome.failed =>
        'Lembrete salvo, mas o celular não aceitou o agendamento.',
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete() async {
    await ref.read(reminderSchedulerProvider).delete(widget.reminder!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.reminder == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Lembrar de...'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: Icons.calendar_today_outlined,
                label: '${weekdayShort(_day)}, ${formatDate(_day)}',
                onTap: () async {
                  final d = await pickDate(
                    context,
                    initial: _day,
                    first: dateOnly(DateTime.now()),
                  );
                  if (d != null) setState(() => _day = dateOnly(d));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PickerField(
                icon: Icons.schedule,
                label: formatTime(_when),
                onTap: () async {
                  final t = await pickTime(context, initial: _time);
                  if (t != null) setState(() => _time = t);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Detalhes (opcional)'),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.reminder != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir lembrete'),
          ),
        ],
      ],
    );
  }
}
