import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../data/agenda_repository.dart';

/// Abre o formulário de evento (novo ou edição).
void openEventForm(
  BuildContext context, {
  AgendaEvent? event,
  DateTime? initialDay,
}) {
  showFormSheet<void>(
    context,
    title: event == null ? 'Novo evento' : 'Editar evento',
    builder: (_) => _EventForm(event: event, initialDay: initialDay),
  );
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.event, this.initialDay});
  final AgendaEvent? event;
  final DateTime? initialDay;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _notes = TextEditingController(text: widget.event?.notes);
  late DateTime _day = dateOnly(
    widget.event?.startsAt ?? widget.initialDay ?? DateTime.now(),
  );
  late bool _allDay = widget.event?.allDay ?? false;
  late TimeOfDay _start = widget.event == null
      ? _nextHour()
      : TimeOfDay.fromDateTime(widget.event!.startsAt);
  late TimeOfDay? _end = widget.event?.endsAt == null
      ? null
      : TimeOfDay.fromDateTime(widget.event!.endsAt!);

  static TimeOfDay _nextHour() {
    final now = DateTime.now();
    return TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
  }

  DateTime _at(TimeOfDay t) =>
      DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Digite o título do evento.');
      return;
    }
    final startsAt = _allDay ? _day : _at(_start);
    DateTime? endsAt;
    if (!_allDay && _end != null) {
      endsAt = _at(_end!);
      // Fim antes do início: entende que o evento termina no dia seguinte.
      if (!endsAt.isAfter(startsAt)) endsAt = addDays(endsAt, 1);
    }
    final notes = _notes.text.trim();
    await ref
        .read(agendaRepositoryProvider)
        .save(
          id: widget.event?.id,
          title: title,
          notes: notes.isEmpty ? null : notes,
          startsAt: startsAt,
          endsAt: endsAt,
          allDay: _allDay,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(agendaRepositoryProvider).delete(widget.event!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.event == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Título'),
        ),
        const SizedBox(height: 12),
        PickerField(
          icon: Icons.calendar_today_outlined,
          label: '${weekdayLong(_day)}, ${formatDate(_day)}',
          onTap: () async {
            final d = await pickDate(context, initial: _day);
            if (d != null) setState(() => _day = dateOnly(d));
          },
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('Dia todo'),
          value: _allDay,
          onChanged: (v) => setState(() => _allDay = v),
        ),
        if (!_allDay) ...[
          Row(
            children: [
              Expanded(
                child: PickerField(
                  icon: Icons.schedule,
                  label: 'Início ${_start.hour.toString().padLeft(2, '0')}:'
                      '${_start.minute.toString().padLeft(2, '0')}',
                  onTap: () async {
                    final t = await pickTime(context, initial: _start);
                    if (t != null) setState(() => _start = t);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PickerField(
                  icon: Icons.schedule_outlined,
                  label: _end == null
                      ? 'Fim (opcional)'
                      : 'Fim ${_end!.hour.toString().padLeft(2, '0')}:'
                            '${_end!.minute.toString().padLeft(2, '0')}',
                  onTap: () async {
                    final t = await pickTime(context, initial: _end ?? _start);
                    if (t != null) setState(() => _end = t);
                  },
                  onClear: _end == null
                      ? null
                      : () => setState(() => _end = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Observações (opcional)'),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.event != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir evento'),
          ),
        ],
      ],
    );
  }
}
