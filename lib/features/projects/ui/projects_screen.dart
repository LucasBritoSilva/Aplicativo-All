import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';

class ProjectsRepository {
  ProjectsRepository(this._db);
  final AppDatabase _db;

  Stream<List<ProjectIdea>> watchAll() => (_db.select(
    _db.projectIdeas,
  )..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).watch();

  Future<void> save({
    int? id,
    required String title,
    String? description,
    String? tools,
    String? notes,
    required ProjectStage stage,
  }) async {
    final data = ProjectIdeasCompanion(
      title: Value(title),
      description: Value(description),
      tools: Value(tools),
      notes: Value(notes),
      stage: Value(stage),
      updatedAt: Value(DateTime.now()),
    );
    if (id == null) {
      await _db.into(_db.projectIdeas).insert(data);
    } else {
      await (_db.update(
        _db.projectIdeas,
      )..where((p) => p.id.equals(id))).write(data);
    }
  }

  Future<void> setStage(int id, ProjectStage stage) =>
      (_db.update(_db.projectIdeas)..where((p) => p.id.equals(id))).write(
        ProjectIdeasCompanion(
          stage: Value(stage),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.projectIdeas)..where((p) => p.id.equals(id))).go();
}

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(ref.watch(databaseProvider)),
);

final projectsProvider = StreamProvider<List<ProjectIdea>>(
  (ref) => ref.watch(projectsRepositoryProvider).watchAll(),
);

Color stageColor(ProjectStage s) => switch (s) {
  ProjectStage.idea => AppColors.textMuted,
  ProjectStage.planned => AppColors.info,
  ProjectStage.inProgress => AppColors.primary,
  ProjectStage.done => AppColors.success,
};

/// Ideias de projetos com ferramentas planejadas e estágio.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  ProjectStage? _stage;
  String _query = '';

  Future<void> _open([ProjectIdea? p]) async {
    final r = await showQuickForm(
      context,
      title: p == null ? 'Nova ideia de projeto' : 'Editar projeto',
      deleteLabel: p == null ? null : 'Excluir projeto',
      fields: [
        TextSpec(
          'title',
          'Título',
          initial: p?.title,
          required: true,
          autofocus: p == null,
        ),
        TextSpec('description', 'Descrição', initial: p?.description, lines: 4),
        TextSpec(
          'tools',
          'Ferramentas e tecnologias planejadas',
          initial: p?.tools,
          lines: 3,
        ),
        ChoiceSpec<ProjectStage>(
          'stage',
          'Estágio',
          options: [for (final s in ProjectStage.values) (s, s.label)],
          initial: p?.stage ?? ProjectStage.idea,
        ),
        TextSpec('notes', 'Observações', initial: p?.notes, lines: 4),
      ],
    );
    if (r == null || !mounted) return;
    final repo = ref.read(projectsRepositoryProvider);
    if (r.deleted) {
      final ok = await confirm(
        context,
        title: 'Excluir projeto',
        message: '"${p!.title}" será apagado.',
        confirmLabel: 'Excluir',
        destructive: true,
      );
      if (ok) await repo.delete(p.id);
      return;
    }
    await repo.save(
      id: p?.id,
      title: r.text('title'),
      description: r.textOrNull('description'),
      tools: r.textOrNull('tools'),
      notes: r.textOrNull('notes'),
      stage: r.choice<ProjectStage>('stage'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ideias de projetos')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova ideia',
        onPressed: _open,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar projetos',
            onChanged: (v) => setState(() => _query = v),
          ),
          FilterBar<ProjectStage?>(
            options: [
              (null, 'Todos'),
              for (final s in ProjectStage.values) (s, s.label),
            ],
            selected: _stage,
            onSelected: (s) => setState(() => _stage = s),
          ),
          Expanded(
            child: projects.view((all) {
              final shown = [
                for (final p in all)
                  if ((_stage == null || p.stage == _stage) &&
                      matchesQuery(_query, [
                        p.title,
                        p.description,
                        p.tools,
                        p.notes,
                      ]))
                    p,
              ];
              if (shown.isEmpty) {
                return EmptyState(
                  icon: Icons.lightbulb_outline,
                  title: all.isEmpty
                      ? 'Nenhuma ideia ainda'
                      : 'Nada encontrado',
                  message: all.isEmpty
                      ? 'Anote ideias de projetos, as ferramentas que pretende '
                            'usar e acompanhe o estágio de cada uma.'
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = shown[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(p),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                PopupMenuButton<ProjectStage>(
                                  tooltip: 'Mudar estágio',
                                  initialValue: p.stage,
                                  onSelected: (s) => ref
                                      .read(projectsRepositoryProvider)
                                      .setStage(p.id, s),
                                  itemBuilder: (_) => [
                                    for (final s in ProjectStage.values)
                                      PopupMenuItem(
                                        value: s,
                                        child: Text(s.label),
                                      ),
                                  ],
                                  child: Pill(
                                    p.stage.label,
                                    color: stageColor(p.stage),
                                    icon: Icons.expand_more,
                                  ),
                                ),
                              ],
                            ),
                            if (p.description != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                p.description!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            if (p.tools != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.build_outlined,
                                    size: 16,
                                    color: AppColors.textFaint,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.tools!,
                                      style: const TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
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
