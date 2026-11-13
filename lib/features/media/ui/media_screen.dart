import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/media_repository.dart';
import '../domain/media_logic.dart';

enum _View {
  toWatch('Para assistir'),
  watched('Assistidos'),
  ranking('Ranking');

  const _View(this.label);
  final String label;
}

/// Entretenimento: títulos organizados em categorias criadas pelo usuário.
class MediaScreen extends ConsumerWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mediaProvider);
    final categories = data.value?.categories ?? const <MediaCategory>[];
    return data.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Entretenimento')),
        body: const Loading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Entretenimento')),
        body: ErrorText(e),
      ),
      data: (d) {
        final actions = [
          IconButton(
            tooltip: 'O que assistir?',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => showDraw(context),
          ),
          IconButton(
            tooltip: 'Categorias',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _CategoriesScreen(),
              ),
            ),
          ),
        ];
        if (categories.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Entretenimento'),
              actions: actions,
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    icon: Icons.movie_outlined,
                    title: 'Nenhuma categoria',
                    message:
                        'Crie categorias como Filmes, Séries ou Documentários '
                        'para organizar o que você quer assistir.',
                  ),
                  FilledButton.icon(
                    onPressed: () => openCategoryForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar categoria'),
                  ),
                ],
              ),
            ),
          );
        }
        return DefaultTabController(
          // Recria as abas quando as categorias mudam.
          key: ValueKey(categories.map((c) => c.id).join(',')),
          length: categories.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Entretenimento'),
              actions: actions,
              bottom: TabBar(
                isScrollable: categories.length > 3,
                tabAlignment: categories.length > 3
                    ? TabAlignment.start
                    : TabAlignment.fill,
                tabs: [for (final c in categories) Tab(text: c.name)],
              ),
            ),
            body: TabBarView(
              children: [
                for (final c in categories) _CategoryTab(categoryId: c.id),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Cadastro ou edição de uma categoria.
Future<void> openCategoryForm(
  BuildContext context,
  WidgetRef ref, [
  MediaCategory? c,
]) async {
  final r = await showQuickForm(
    context,
    title: c == null ? 'Nova categoria' : 'Editar categoria',
    fields: [
      TextSpec(
        'name',
        'Nome (ex.: Documentários)',
        initial: c?.name,
        required: true,
        autofocus: c == null,
      ),
      SwitchSpec(
        'episodes',
        'Acompanhar temporadas e episódios',
        initial: c?.hasEpisodes ?? false,
        subtitle: 'Para séries, animes, novelas e parecidos',
      ),
    ],
  );
  if (r == null) return;
  await ref
      .read(mediaRepositoryProvider)
      .saveCategory(
        id: c?.id,
        name: r.text('name'),
        hasEpisodes: r.flag('episodes'),
      );
}

/// Exclusão segura: com títulos, pede para mover ou confirmar a exclusão.
Future<void> deleteCategory(
  BuildContext context,
  WidgetRef ref,
  MediaCategory c,
  MediaData data,
) async {
  final repo = ref.read(mediaRepositoryProvider);
  final items = data.itemsOf(c.id);
  if (items.isEmpty) {
    final ok = await confirm(
      context,
      title: 'Excluir categoria',
      message: 'A categoria "${c.name}" está vazia e será excluída.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteCategory(c.id);
    return;
  }
  final others = data.categories.where((x) => x.id != c.id).toList();
  final r = await showQuickForm(
    context,
    title: 'Excluir "${c.name}"',
    submitLabel: 'Continuar',
    fields: [
      ChoiceSpec<int>(
        'target',
        'O que fazer com os ${items.length} títulos?',
        options: [
          for (final o in others) (o.id, 'Mover para ${o.name}'),
          (-1, 'Excluir os títulos junto'),
        ],
        initial: others.isEmpty ? -1 : others.first.id,
      ),
    ],
  );
  if (r == null || !context.mounted) return;
  final target = r.choice<int>('target');
  if (target == -1) {
    final ok = await confirm(
      context,
      title: 'Excluir títulos?',
      message:
          'A categoria "${c.name}" e os ${items.length} títulos dela serão '
          'apagados. Isso não pode ser desfeito.',
      confirmLabel: 'Excluir tudo',
      destructive: true,
    );
    if (ok) await repo.deleteCategory(c.id, deleteItems: true);
  } else {
    await repo.deleteCategory(c.id, moveTo: target);
    if (context.mounted) {
      showMessage(context, 'Títulos movidos e categoria excluída.');
    }
  }
}

class _CategoriesScreen extends ConsumerWidget {
  const _CategoriesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mediaProvider);
    final repo = ref.read(mediaRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova categoria',
        onPressed: () => openCategoryForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: data.view((d) {
        if (d.categories.isEmpty) {
          return const EmptyState(
            icon: Icons.category_outlined,
            title: 'Nenhuma categoria',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              child: Column(
                children: [
                  for (final (i, c) in d.categories.indexed)
                    ListTile(
                      title: Text(c.name),
                      subtitle: Text(
                        '${d.itemsOf(c.id).length} títulos'
                        '${c.hasEpisodes ? ' · com episódios' : ''}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      onTap: () => openCategoryForm(context, ref, c),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Mover para cima',
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            onPressed: i == 0
                                ? null
                                : () => repo.moveCategory(c.id, -1),
                          ),
                          IconButton(
                            tooltip: 'Excluir categoria',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => deleteCategory(context, ref, c, d),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CategoryTab extends ConsumerStatefulWidget {
  const _CategoryTab({required this.categoryId});
  final int categoryId;

  @override
  ConsumerState<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends ConsumerState<_CategoryTab> {
  _View _view = _View.toWatch;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mediaProvider);
    return data.view((d) {
      final category = d.category(widget.categoryId);
      if (category == null) return const SizedBox.shrink();
      final ofCategory = [
        for (final m in d.itemsOf(category.id))
          if (matchesQuery(_query, [m.title, m.notes])) m,
      ];
      final list = switch (_view) {
        _View.toWatch => ofCategory.where((m) => !m.watched).toList(),
        _View.watched => ofCategory.where((m) => m.watched).toList(),
        _View.ranking => rankWatched(ofCategory, mediaEntry),
      };
      return Scaffold(
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          tooltip: 'Adicionar em ${category.name}',
          onPressed: () => openMediaForm(context, ref, d, category),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            SearchField(
              hint: 'Buscar em ${category.name}',
              onChanged: (v) => setState(() => _query = v),
            ),
            FilterBar<_View>(
              options: [for (final v in _View.values) (v, v.label)],
              selected: _view,
              onSelected: (v) => setState(() => _view = v),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.movie_outlined,
                      title: switch (_view) {
                        _View.toWatch => 'Nada para assistir aqui',
                        _View.watched => 'Nada assistido ainda',
                        _View.ranking => 'Ranking vazio',
                      },
                      message: _view == _View.ranking
                          ? 'O ranking mostra só os assistidos que têm nota.'
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _MediaCard(
                        item: list[i],
                        category: category,
                        data: d,
                        position: _view == _View.ranking ? i + 1 : null,
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }
}

Future<void> openMediaForm(
  BuildContext context,
  WidgetRef ref,
  MediaData data,
  MediaCategory category, [
  MediaItem? m,
]) async {
  // Primeira etapa: em qual categoria (só ao editar, para poder mover).
  var target = category;
  final r = await showQuickForm(
    context,
    title: m == null ? 'Adicionar em ${category.name}' : 'Editar',
    deleteLabel: m == null ? null : 'Excluir',
    fields: [
      TextSpec(
        'title',
        'Título',
        initial: m?.title,
        required: true,
        autofocus: m == null,
        capitalization: TextCapitalization.words,
      ),
      if (m != null && data.categories.length > 1)
        ChoiceSpec<int>(
          'category',
          'Categoria',
          options: [for (final c in data.categories) (c.id, c.name)],
          initial: category.id,
        ),
      NumberSpec(
        'rating',
        'Nota de 0 a 10 (opcional)',
        initial: m?.rating,
        min: 0,
        max: 10,
      ),
      if (category.hasEpisodes) ...[
        NumberSpec(
          'season',
          'Temporada atual',
          initial: m?.season?.toDouble(),
          decimal: false,
          min: 1,
        ),
        NumberSpec(
          'episode',
          'Episódio atual',
          initial: m?.episode?.toDouble(),
          decimal: false,
          min: 0,
        ),
        NumberSpec(
          'total',
          'Total de episódios (opcional)',
          initial: m?.totalEpisodes?.toDouble(),
          decimal: false,
          min: 1,
        ),
      ],
      TextSpec('notes', 'Observações', initial: m?.notes, lines: 3),
    ],
    validate: (v) {
      final ep = v.integer('episode'), total = v.integer('total');
      if (ep != null && total != null && ep > total) {
        return 'O episódio atual passa do total de episódios.';
      }
      return null;
    },
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(mediaRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir',
      message: '"${m!.title}" será removido.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteItem(m.id);
    return;
  }
  if (m != null && data.categories.length > 1) {
    target = data.category(r.choice<int>('category')) ?? category;
  }
  await repo.saveItem(
    id: m?.id,
    category: target,
    title: r.text('title'),
    rating: r.number('rating'),
    season: r.integer('season') ?? m?.season,
    episode: r.integer('episode') ?? m?.episode,
    totalEpisodes: r.integer('total') ?? m?.totalEpisodes,
    notes: r.textOrNull('notes'),
  );
}

class _MediaCard extends ConsumerWidget {
  const _MediaCard({
    required this.item,
    required this.category,
    required this.data,
    this.position,
  });

  final MediaItem item;
  final MediaCategory category;
  final MediaData data;
  final int? position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = item;
    final repo = ref.read(mediaRepositoryProvider);
    final progress = episodeProgress(m.episode, m.totalEpisodes);
    final episodeText =
        category.hasEpisodes && (m.season != null || m.episode != null)
        ? 'T${m.season ?? 1} · E${m.episode ?? 0}'
              '${m.totalEpisodes == null ? '' : ' de ${m.totalEpisodes}'}'
        : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMediaForm(context, ref, data, category, m),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            children: [
              if (position != null)
                SizedBox(
                  width: 44,
                  child: Text(
                    '$positionº',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                Checkbox(
                  value: m.watched,
                  onChanged: (v) => repo.setWatched(m.id, v ?? false),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (m.rating != null)
                          Pill(
                            'Nota ${formatNumber(m.rating!)}',
                            color: AppColors.primary,
                            icon: Icons.star_rounded,
                          ),
                        if (m.watched)
                          const Pill('Assistido', color: AppColors.success),
                        if (episodeText != null)
                          Pill(episodeText, icon: Icons.tv),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ProgressBar(value: progress),
                    ],
                  ],
                ),
              ),
              if (category.hasEpisodes && !m.watched)
                IconButton(
                  tooltip: 'Marcar próximo episódio',
                  icon: const Icon(Icons.exposure_plus_1),
                  onPressed: () => repo.nextEpisode(m),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sorteio "O que assistir?" entre os títulos ainda não assistidos.
void showDraw(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => const _DrawSheet(),
  );
}

class _DrawSheet extends ConsumerStatefulWidget {
  const _DrawSheet();

  @override
  ConsumerState<_DrawSheet> createState() => _DrawSheetState();
}

class _DrawSheetState extends ConsumerState<_DrawSheet> {
  int? _categoryId;
  MediaItem? _picked;
  bool _empty = false;

  void _draw(List<MediaItem> items) {
    final next = drawUnwatched(
      items,
      mediaEntry,
      categoryId: _categoryId,
      avoidId: _picked?.id,
    );
    setState(() {
      _picked = next;
      _empty = next == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mediaProvider).value;
    final items = data?.items ?? const <MediaItem>[];
    final categories = data?.categories ?? const <MediaCategory>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'O que assistir?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _categoryId == null,
                onSelected: (_) => setState(() => _categoryId = null),
              ),
              for (final c in categories)
                ChoiceChip(
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: _empty
                ? const Text(
                    'Nenhum título não assistido nesta categoria.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : _picked == null
                ? const Text(
                    'Toque em Sortear',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _picked!.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data?.category(_picked!.categoryId)?.name ?? '',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _draw(items),
            icon: const Icon(Icons.casino_outlined),
            label: Text(_picked == null ? 'Sortear' : 'Sortear de novo'),
          ),
        ],
      ),
    );
  }
}
