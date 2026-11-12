import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../data/routine_repository.dart';
import '../data/routine_sync.dart';
import '../domain/routine_logic.dart';

const _weekdayChips = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Abre o cadastro de uma atividade recorrente (ou de data única).
Future<void> openActivityForm(
  BuildContext context, {
  RoutineActivity? activity,
}) {
  return showFormSheet<void>(
    context,
    title: activity == null ? 'Nova atividade' : 'Editar atividade',
    builder: (_) => _ActivityForm(activity: activity),
  );
}

class _ActivityForm extends ConsumerStatefulWidget {
  const _ActivityForm({this.activity});

  final RoutineActivity? activity;

  @override
  ConsumerState<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends ConsumerState<_ActivityForm> {
  late final _name = TextEditingController(text: widget.activity?.name);
  late final _description = TextEditingController(
    text: widget.activity?.description,
  );
  late ActivityKind _kind = widget.activity?.kind ?? ActivityKind.flexible;
  late int _start = widget.activity?.startMinute ?? 8 * 60;
  late int _end = widget.activity?.endMinute ?? 9 * 60;
  late bool _weekly = widget.activity?.singleDay == null;
  late int _mask = widget.activity?.weekdays ?? 0;
  late int? _singleDay = widget.activity?.singleDay;
  late bool _timer = widget.activity?.timerEnabled ?? false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await pickTime(
      context,
      initial: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minute = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        // Mantém a duração ao mudar o início.
        final duration = _end - _start;
        _start = minute;
        if (duration > 0 && minute + duration <= 1439) _end = minute + duration;
      } else {
        _end = minute;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final singleDay = _weekly ? null : _singleDay;
    final mask = _weekly ? _mask : 0;
    final error = !_weekly && singleDay == null
        ? 'Escolha a data do compromisso.'
        : validateActivity(
            name: name,
            startMinute: _start,
            endMinute: _end,
            weekdays: mask,
            singleDay: singleDay,
          );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      // Avisa se o novo planejamento se sobrepõe a outra atividade.
      final others = await ref.read(routineRepositoryProvider).activeActivities();
      final conflicts = [
        for (final o in others)
          if (o.id != widget.activity?.id &&
              plansOverlap(
                startA: _start,
                endA: _end,
                weekdaysA: mask,
                singleDayA: singleDay,
                startB: o.startMinute,
                endB: o.endMinute,
                weekdaysB: o.weekdays,
                singleDayB: o.singleDay,
              ))
            o,
      ];
      if (conflicts.isNotEmpty) {
        if (!mounted) return;
        final keep = await confirm(
          context,
          title: 'Conflito de horário',
          message:
              'Esse horário se sobrepõe a:\n\n'
              '${conflicts.map((c) => '• ${c.name}, ${formatMinute(c.startMinute)}–${formatMinute(c.endMinute)}${c.kind == ActivityKind.fixed ? ' (compromisso fixo)' : ''}').join('\n')}\n\n'
              'Deseja salvar mesmo assim?',
          confirmLabel: 'Salvar',
        );
        if (!keep) return;
      }

      final description = _description.text.trim();
      await ref
          .read(routineActionsProvider)
          .saveActivity(
            id: widget.activity?.id,
            name: name,
            description: description.isEmpty ? null : description,
            kind: _kind,
            startMinute: _start,
            endMinute: _end,
            weekdays: mask,
            singleDay: singleDay,
            timerEnabled: _kind != ActivityKind.rest && _timer,
          );

      // Pede a permissão de notificação só quando ela passa a ser útil.
      if (_kind != ActivityKind.rest) {
        try {
          final permissions = ref.read(permissionServiceProvider);
          if (await permissions.notificationStatus() !=
              PermissionState.granted) {
            await permissions.requestNotifications();
            await ref.read(routineSyncProvider).syncNotifications();
          }
        } catch (_) {
          // Sem a permissão o app segue funcionando, só não avisa.
        }
      }
      if (mounted) Navigator.pop(context);
    } on RoutineStateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirm(
      context,
      title: 'Remover do planejamento?',
      message:
          'As próximas ocorrências desta atividade deixam de aparecer. '
          'O histórico do que já aconteceu é mantido.',
      confirmLabel: 'Remover',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(routineActionsProvider).archiveActivity(widget.activity!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final single = _singleDay == null ? null : dateFromEpochDay(_singleDay!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: widget.activity == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
        ),
        const SizedBox(height: 16),
        const Text('Tipo', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final kind in ActivityKind.values)
              ChoiceChip(
                label: Text(kind.label),
                selected: _kind == kind,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: Icons.schedule,
                label: 'Início ${formatMinute(_start)}',
                onTap: () => _pickTime(start: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PickerField(
                icon: Icons.schedule,
                label: 'Fim ${formatMinute(_end)}',
                onTap: () => _pickTime(start: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: true, label: Text('Repetir na semana')),
            ButtonSegment(value: false, label: Text('Data única')),
          ],
          selected: {_weekly},
          onSelectionChanged: (s) => setState(() => _weekly = s.first),
        ),
        const SizedBox(height: 12),
        if (_weekly) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(_weekdayChips[day - 1]),
                  selected: maskHasWeekday(_mask, day),
                  onSelected: (on) => setState(() {
                    _mask = on ? _mask | (1 << (day - 1)) : _mask & ~(1 << (day - 1));
                  }),
                ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _mask = allWeekdaysMask),
                child: const Text('Todos os dias'),
              ),
              TextButton(
                onPressed: () => setState(() => _mask = workdaysMask),
                child: const Text('Segunda a sexta'),
              ),
            ],
          ),
        ] else
          PickerField(
            icon: Icons.event_outlined,
            label: single == null
                ? 'Escolher a data'
                : '${weekdayShort(single)}, ${formatDate(single)}',
            onTap: () async {
              final picked = await pickDate(
                context,
                initial: single,
                first: dateOnly(DateTime.now()),
              );
              if (picked != null) {
                setState(() => _singleDay = epochDay(picked));
              }
            },
          ),
        if (_kind != ActivityKind.rest)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar cronômetro'),
            subtitle: const Text(
              'Conta o tempo realmente dedicado a esta atividade',
              style: TextStyle(color: AppColors.textMuted),
            ),
            value: _timer,
            onChanged: (v) => setState(() => _timer = v),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
        if (widget.activity != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _remove,
            child: const Text('Remover do planejamento'),
          ),
        ],
      ],
    );
  }
}
