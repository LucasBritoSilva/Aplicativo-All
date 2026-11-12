import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../data/agenda_repository.dart';
import '../domain/agenda_logic.dart';
import 'event_form.dart';

enum _AgendaView { day, week }

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  _AgendaView _view = _AgendaView.day;
  DateTime _selected = dateOnly(DateTime.now());

  (DateTime, DateTime) get _range {
    if (_view == _AgendaView.day) return (_selected, addDays(_selected, 1));
    final start = startOfWeek(_selected);
    return (start, addDays(start, 7));
  }

  void _move(int direction) {
    setState(() {
      _selected = addDays(
        _selected,
        direction * (_view == _AgendaView.day ? 1 : 7),
      );
    });
  }

  String _label(DateTime today) {
    if (_view == _AgendaView.day) {
      final friendly = friendlyDay(_selected, today);
      final full = '${weekdayShort(_selected)}, ${formatDayMonth(_selected)}';
      return friendly == full ? full : '$friendly · $full';
    }
    return formatWeekRange(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final events = ref.watch(agendaRangeProvider(_range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _selected = today),
            child: const Text('Hoje'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo evento',
        onPressed: () => openEventForm(context, initialDay: _selected),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_AgendaView>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _AgendaView.day, label: Text('Dia')),
                ButtonSegment(value: _AgendaView.week, label: Text('Semana')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _move(-1),
                ),
                Expanded(
                  child: Text(
                    _label(today),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _move(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: events.when(
              loading: () => const Loading(),
              error: (e, _) => ErrorText(e),
              data: (list) => _view == _AgendaView.day
                  ? _DayView(events: list, day: _selected)
                  : _WeekView(
                      events: list,
                      anyDay: _selected,
                      today: today,
                      onOpenDay: (d) => setState(() {
                        _selected = d;
                        _view = _AgendaView.day;
                      }),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

List<AgendaEvent> _eventsOf(List<AgendaEvent> all, DateTime day) => all
    .where(
      (e) => eventOnDay(startsAt: e.startsAt, endsAt: e.endsAt, day: day),
    )
    .toList();

String _timeLabel(AgendaEvent e) {
  if (e.allDay) return 'Dia todo';
  final start = formatTime(e.startsAt);
  if (e.endsAt == null) return start;
  return '$start – ${formatTime(e.endsAt!)}';
}

class _DayView extends StatelessWidget {
  const _DayView({required this.events, required this.day});

  final List<AgendaEvent> events;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final list = _eventsOf(events, day);
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nada marcado neste dia',
        message: 'Toque em + para criar um evento.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = list[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openEventForm(context, event: e),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timeLabel(e),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (e.notes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.notes!,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.events,
    required this.anyDay,
    required this.today,
    required this.onOpenDay,
  });

  final List<AgendaEvent> events;
  final DateTime anyDay;
  final DateTime today;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final days = daysOfWeek(anyDay);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final day = days[i];
        final list = _eventsOf(events, day);
        final isToday = isSameDay(day, today);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpenDay(day),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Column(
                      children: [
                        Text(
                          weekdayShort(day),
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? AppColors.onPrimary
                                  : AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: Text(
                              'Livre',
                              style: TextStyle(color: AppColors.textFaint),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final e in list)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${_timeLabel(e)}  ',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        TextSpan(text: e.title),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
