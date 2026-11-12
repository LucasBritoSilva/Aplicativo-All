import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../domain/counter_logic.dart';

class CountersRepository {
  CountersRepository(this._db);
  final AppDatabase _db;

  Stream<List<DayCounter>> watchAll() => (_db.select(
    _db.dayCounters,
  )..orderBy([(c) => OrderingTerm.asc(c.day)])).watch();

  Future<void> save({
    int? id,
    required String title,
    required int day,
    String? description,
  }) async {
    final data = DayCountersCompanion(
      title: Value(title),
      day: Value(day),
      description: Value(description),
    );
    if (id == null) {
      await _db.into(_db.dayCounters).insert(data);
    } else {
      await (_db.update(_db.dayCounters)..where((c) => c.id.equals(id))).write(data);
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.dayCounters)..where((c) => c.id.equals(id))).go();
}

final countersRepositoryProvider = Provider<CountersRepository>(
  (ref) => CountersRepository(ref.watch(databaseProvider)),
);

final countersProvider = StreamProvider<List<DayCounter>>(
  (ref) => ref.watch(countersRepositoryProvider).watchAll(),
);

/// Contadores de dias: quanto falta ou quanto passou.
class CountersScreen extends ConsumerWidget {
  const CountersScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, [DayCounter? c]) async {
    final r = await showQuickForm(
      context,
      title: c == null ? 'Novo contador' : 'Editar contador',
      deleteLabel: c == null ? null : 'Excluir contador',
      fields: [
        TextSpec('title', 'Título', initial: c?.title, required: true, autofocus: c == null),
        DateSpec(
          'day',
          'Data',
          initial: c == null ? null : dateFromEpochDay(c.day),
          required: true,
        ),
        TextSpec('description', 'Descrição (opcional)', initial: c?.description, lines: 3),
      ],
    );
    if (r == null || !context.mounted) return;
    final repo = ref.read(countersRepositoryProvider);
    if (r.deleted) {
      final ok = await confirm(
        context,
        title: 'Excluir contador',
        message: '"${c!.title}" será apagado.',
        confirmLabel: 'Excluir',
        destructive: true,
      );
      if (ok) await repo.delete(c.id);
      return;
    }
    await repo.save(
      id: c?.id,
      title: r.text('title'),
      day: epochDay(r.date('day')!),
      description: r.textOrNull('description'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = epochDay(ref.watch(todayProvider));
    final counters = ref.watch(countersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contador de dias')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo contador',
        onPressed: () => _open(context, ref),
        child: const Icon(Icons.add),
      ),
      body: counters.view((list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.hourglass_bottom,
            title: 'Nenhum contador',
            message:
                'Conte os dias que faltam para um acontecimento ou os dias '
                'que já passaram desde ele.',
          );
        }
        final sorted = [...list]
          ..sort((a, b) => compareCounters(a.day, b.day, today));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = sorted[i];
            final count = countDays(c.day, today);
            final color = switch (count.direction) {
              CounterDirection.today => AppColors.success,
              CounterDirection.future => AppColors.primary,
              CounterDirection.past => AppColors.textMuted,
            };
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(context, ref, c),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            FittedBox(
                              child: Text(
                                count.direction == CounterDirection.today
                                    ? '🎉'
                                    : '${count.days}',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            Text(
                              count.direction == CounterDirection.today
                                  ? 'hoje'
                                  : (count.days == 1 ? 'dia' : 'dias'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${count.label} · ${formatDate(dateFromEpochDay(c.day))}',
                              style: TextStyle(color: color, fontSize: 13),
                            ),
                            if (c.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                c.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
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
      }),
    );
  }
}
