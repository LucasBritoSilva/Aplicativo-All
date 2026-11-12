import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/events_repository.dart';

String money(double v) => 'R\$ ${formatNumber(v)}';

/// Abre o cadastro do evento. Devolve o id salvo (ou nulo).
Future<int?> openEventForm(
  BuildContext context,
  WidgetRef ref, [
  SocialEvent? e,
]) async {
  final r = await showQuickForm(
    context,
    title: e == null ? 'Novo evento' : 'Editar evento',
    deleteLabel: e == null ? null : 'Excluir evento',
    fields: [
      TextSpec(
        'name',
        'Nome do evento',
        initial: e?.name,
        required: true,
        autofocus: e == null,
      ),
      DateSpec(
        'day',
        'Data',
        initial: e == null ? null : dateFromEpochDay(e.day),
        required: true,
      ),
      TimeSpec('time', 'Horário (opcional)', initial: e?.startMinute),
      TextSpec('location', 'Local', initial: e?.location),
      TextSpec('description', 'Descrição', initial: e?.description, lines: 3),
      NumberSpec(
        'budget',
        'Orçamento estimado (opcional)',
        initial: e?.budget,
        min: 0,
        suffix: 'R\$',
      ),
      TextSpec('notes', 'Observações', initial: e?.notes, lines: 3),
    ],
  );
  if (r == null || !context.mounted) return null;
  final repo = ref.read(eventsRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir evento',
      message:
          '"${e!.name}" e tudo o que pertence a ele (convidados, checklist, '
          'itens e gastos) serão apagados.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) {
      await repo.deleteEvent(e.id);
      if (context.mounted) {
        Navigator.of(
          context,
        ).popUntil((r) => r.settings.name == 'eventos' || r.isFirst);
      }
    }
    return null;
  }
  return repo.saveEvent(
    id: e?.id,
    name: r.text('name'),
    day: epochDay(r.date('day')!),
    startMinute: r.time('time'),
    location: r.textOrNull('location'),
    description: r.textOrNull('description'),
    budget: r.number('budget'),
    notes: r.textOrNull('notes'),
  );
}

/// Eventos sociais: próximos e passados.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _past = false;

  void _openDetails(int id) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EventDetailScreen(eventId: id)),
  );

  @override
  Widget build(BuildContext context) {
    final todayDate = ref.watch(todayProvider);
    final today = epochDay(todayDate);
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos sociais')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo evento',
        onPressed: () async {
          final id = await openEventForm(context, ref);
          if (id != null && mounted) _openDetails(id);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          FilterBar<bool>(
            options: const [(false, 'Próximos'), (true, 'Passados')],
            selected: _past,
            onSelected: (v) => setState(() => _past = v),
          ),
          Expanded(
            child: events.view((all) {
              final shown = [
                for (final e in all)
                  if ((e.day < today) == _past) e,
              ];
              if (_past) shown.sort((a, b) => b.day.compareTo(a.day));
              if (shown.isEmpty) {
                return EmptyState(
                  icon: Icons.celebration_outlined,
                  title: _past
                      ? 'Nenhum evento passado'
                      : 'Nenhum evento marcado',
                  message: _past
                      ? null
                      : 'Organize festas e encontros: convidados, checklist, '
                            'o que levar e quanto vai custar.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = shown[i];
                  final date = dateFromEpochDay(e.day);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: () => _openDetails(e.id),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            formatDayMonth(date).split(' ').last,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      title: Text(e.name),
                      subtitle: Text(
                        [
                          friendlyDay(date, todayDate),
                          if (e.startMinute != null)
                            formatMinute(e.startMinute!),
                          if (e.location != null) e.location!,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Detalhes do evento com convidados, checklist, itens e orçamento.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(eventDetailsProvider(eventId));
    final today = ref.watch(todayProvider);
    final repo = ref.read(eventsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(details.value?.event.name ?? 'Evento'),
        actions: [
          if (details.value != null)
            IconButton(
              tooltip: 'Editar evento',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  openEventForm(context, ref, details.value!.event),
            ),
        ],
      ),
      body: details.view((d) {
        if (d == null) {
          return const EmptyState(
            icon: Icons.event_busy,
            title: 'Evento excluído',
          );
        }
        final e = d.event;
        final date = dateFromEpochDay(e.day);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Line(
                      Icons.event,
                      '${friendlyDay(date, today)} · ${weekdayLong(date)}, ${formatDate(date)}'
                      '${e.startMinute == null ? '' : ' às ${formatMinute(e.startMinute!)}'}',
                    ),
                    if (e.location != null)
                      _Line(Icons.place_outlined, e.location!),
                    if (e.description != null)
                      _Line(Icons.notes, e.description!),
                    if (e.notes != null)
                      _Line(Icons.sticky_note_2_outlined, e.notes!),
                  ],
                ),
              ),
            ),
            // Convidados
            _Header(
              'Convidados (${d.guests.length})',
              onAdd: () => _guestForm(context, ref),
            ),
            if (d.guests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '${d.countRsvp(Rsvp.confirmed)} confirmados · '
                  '${d.countRsvp(Rsvp.waiting)} aguardando · '
                  '${d.countRsvp(Rsvp.declined)} recusaram',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            _Box(
              empty: 'Nenhum convidado.',
              children: [
                for (final g in d.guests)
                  ListTile(
                    onTap: () => _guestForm(context, ref, g),
                    title: Text(g.name),
                    trailing: PopupMenuButton<Rsvp>(
                      tooltip: 'Resposta',
                      initialValue: g.rsvp,
                      onSelected: (r) => repo.setRsvp(g.id, r),
                      itemBuilder: (_) => [
                        for (final r in Rsvp.values)
                          PopupMenuItem(value: r, child: Text(r.label)),
                      ],
                      child: Pill(
                        g.rsvp.label,
                        color: _rsvpColor(g.rsvp),
                        icon: Icons.expand_more,
                      ),
                    ),
                  ),
              ],
            ),
            // Checklist
            _Header(
              'Preparação (${d.checklistDone}/${d.checklist.length})',
              onAdd: () async {
                final r = await showQuickForm(
                  context,
                  title: 'Nova tarefa de preparação',
                  fields: const [
                    TextSpec('t', 'Tarefa', required: true, autofocus: true),
                  ],
                );
                if (r != null) await repo.addChecklist(eventId, r.text('t'));
              },
            ),
            _Box(
              empty: 'Nada na checklist.',
              children: [
                for (final c in d.checklist)
                  CheckboxListTile(
                    value: c.done,
                    onChanged: (v) => repo.setChecklistDone(c.id, v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      c.title,
                      style: c.done
                          ? const TextStyle(
                              color: AppColors.textFaint,
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    secondary: IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => repo.deleteChecklist(c.id),
                    ),
                  ),
              ],
            ),
            // Itens necessários
            _Header(
              'Itens necessários',
              onAdd: () => _neededForm(context, ref),
            ),
            _Box(
              empty: 'Nenhum item (comidas, bebidas, materiais).',
              children: [
                for (final n in d.needed)
                  ListTile(
                    onTap: () => _neededForm(context, ref, n),
                    leading: Checkbox(
                      value: n.got,
                      onChanged: (v) => repo.setNeededGot(n.id, v ?? false),
                    ),
                    title: Text(
                      n.name,
                      style: n.got
                          ? const TextStyle(
                              color: AppColors.textFaint,
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    subtitle: Text(
                      [
                        n.category.label,
                        if (n.quantity != null) n.quantity!,
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
            // Orçamento
            _Header(
              'Orçamento e gastos',
              onAdd: () => _expenseForm(context, ref),
            ),
            StatRow(
              tiles: [
                StatTile(
                  value: e.budget == null ? '—' : money(e.budget!),
                  label: 'Orçamento',
                ),
                StatTile(value: money(d.spent), label: 'Gasto'),
                StatTile(
                  value: d.balance == null ? '—' : money(d.balance!.abs()),
                  label: d.balance == null
                      ? 'Saldo'
                      : (d.balance! >= 0 ? 'Disponível' : 'Acima do orçamento'),
                  color: d.balance != null && d.balance! < 0
                      ? AppColors.danger
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Box(
              empty: 'Nenhum gasto lançado.',
              children: [
                for (final x in d.expenses)
                  ListTile(
                    onTap: () => _expenseForm(context, ref, x),
                    title: Text(x.description),
                    trailing: Text(money(x.amount)),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Color _rsvpColor(Rsvp r) => switch (r) {
    Rsvp.confirmed => AppColors.success,
    Rsvp.declined => AppColors.danger,
    Rsvp.waiting => AppColors.textMuted,
  };

  Future<void> _guestForm(
    BuildContext context,
    WidgetRef ref, [
    EventGuest? g,
  ]) async {
    final r = await showQuickForm(
      context,
      title: g == null ? 'Novo convidado' : 'Editar convidado',
      deleteLabel: g == null ? null : 'Remover convidado',
      fields: [
        TextSpec(
          'name',
          'Nome',
          initial: g?.name,
          required: true,
          autofocus: g == null,
          capitalization: TextCapitalization.words,
        ),
        ChoiceSpec<Rsvp>(
          'rsvp',
          'Resposta',
          options: [for (final r in Rsvp.values) (r, r.label)],
          initial: g?.rsvp ?? Rsvp.waiting,
        ),
      ],
    );
    if (r == null) return;
    final repo = ref.read(eventsRepositoryProvider);
    if (r.deleted) {
      await repo.deleteGuest(g!.id);
    } else {
      await repo.saveGuest(
        eventId,
        id: g?.id,
        name: r.text('name'),
        rsvp: r.choice<Rsvp>('rsvp'),
      );
    }
  }

  Future<void> _neededForm(
    BuildContext context,
    WidgetRef ref, [
    EventNeededItem? n,
  ]) async {
    final r = await showQuickForm(
      context,
      title: n == null ? 'Novo item' : 'Editar item',
      deleteLabel: n == null ? null : 'Remover item',
      fields: [
        TextSpec(
          'name',
          'Item',
          initial: n?.name,
          required: true,
          autofocus: n == null,
        ),
        ChoiceSpec<NeededCategory>(
          'cat',
          'Tipo',
          options: [for (final c in NeededCategory.values) (c, c.label)],
          initial: n?.category ?? NeededCategory.food,
        ),
        TextSpec('qty', 'Quantidade (opcional)', initial: n?.quantity),
      ],
    );
    if (r == null) return;
    final repo = ref.read(eventsRepositoryProvider);
    if (r.deleted) {
      await repo.deleteNeeded(n!.id);
    } else {
      await repo.saveNeeded(
        eventId,
        id: n?.id,
        name: r.text('name'),
        category: r.choice<NeededCategory>('cat'),
        quantity: r.textOrNull('qty'),
      );
    }
  }

  Future<void> _expenseForm(
    BuildContext context,
    WidgetRef ref, [
    EventExpense? x,
  ]) async {
    final r = await showQuickForm(
      context,
      title: x == null ? 'Novo gasto' : 'Editar gasto',
      deleteLabel: x == null ? null : 'Excluir gasto',
      fields: [
        TextSpec(
          'desc',
          'Descrição',
          initial: x?.description,
          required: true,
          autofocus: x == null,
        ),
        NumberSpec(
          'amount',
          'Valor',
          initial: x?.amount,
          required: true,
          min: 0,
          suffix: 'R\$',
        ),
      ],
    );
    if (r == null) return;
    final repo = ref.read(eventsRepositoryProvider);
    if (r.deleted) {
      await repo.deleteExpense(x!.id);
    } else {
      await repo.saveExpense(
        eventId,
        id: x?.id,
        description: r.text('desc'),
        amount: r.number('amount')!,
      );
    }
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.title, {required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SectionLabel(
    title,
    padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
    trailing: IconButton(
      tooltip: 'Adicionar',
      icon: const Icon(Icons.add),
      onPressed: onAdd,
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.children, required this.empty});
  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) => children.isEmpty
      ? Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            empty,
            style: const TextStyle(color: AppColors.textFaint),
          ),
        )
      : Card(child: Column(children: children));
}
