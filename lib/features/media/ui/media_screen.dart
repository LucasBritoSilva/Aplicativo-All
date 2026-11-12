import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../domain/media_logic.dart';

MediaEntry mediaEntry(MediaItem m) => (
  id: m.id,
  kind: m.kind,
  title: m.title,
  watched: m.watched,
  rating: m.rating,
);

class MediaRepository {
  MediaRepository(this._db);
  final AppDatabase _db;

  Stream<List<MediaItem>> watchAll() =>
      (_db.select(_db.mediaItems)..orderBy([
            (m) => OrderingTerm.asc(m.title.collate(Collate.noCase)),
          ]))
          .watch();

  Future<void> save({
    int? id,
    required MediaKind kind,
    required String title,
    double? rating,
    int? season,
    int? episode,
    int? totalEpisodes,
    String? notes,
  }) async {
    final data = MediaItemsCompanion(
      kind: Value(kind),
      title: Value(title),
      rating: Value(rating),
      season: Value(season),
      episode: Value(episode),
      totalEpisodes: Value(totalEpisodes),
      notes: Value(notes),
    );
    if (id == null) {
      await _db.into(_db.mediaItems).insert(data);
    } else {
      await (_db.update(
        _db.mediaItems,
      )..where((m) => m.id.equals(id))).write(data);
    }
  }

  Future<void> setWatched(int id, bool watched) =>
      (_db.update(_db.mediaItems)..where((m) => m.id.equals(id))).write(
        MediaItemsCompanion(
          watched: Value(watched),
          watchedAt: Value(watched ? DateTime.now() : null),
        ),
      );

  /// Avança um episódio (sem passar do total, se informado).
  Future<void> nextEpisode(MediaItem m) {
    final next = (m.episode ?? 0) + 1;
    final capped = m.totalEpisodes != null && next > m.totalEpisodes!
        ? m.totalEpisodes!
        : next;
    return (_db.update(_db.mediaItems)..where((x) => x.id.equals(m.id))).write(
      MediaItemsCompanion(episode: Value(capped)),
    );
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.mediaItems)..where((m) => m.id.equals(id))).go();
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(databaseProvider)),
);

final mediaProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(mediaRepositoryProvider).watchAll(),
);

enum _View {
  toWatch('Para assistir'),
  watched('Assistidos'),
  ranking('Ranking');

  const _View(this.label);
  final String label;
}

/// Filmes, séries e animes: três abas independentes.
class MediaScreen extends ConsumerWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Filmes, séries e animes'),
          actions: [
            IconButton(
              tooltip: 'O que assistir?',
              icon: const Icon(Icons.casino_outlined),
              onPressed: () => showDraw(context),
            ),
          ],
          bottom: TabBar(
            tabs: [for (final k in MediaKind.values) Tab(text: k.plural)],
          ),
        ),
        body: TabBarView(
          children: [for (final k in MediaKind.values) _KindTab(kind: k)],
        ),
      ),
    );
  }
}

class _KindTab extends ConsumerStatefulWidget {
  const _KindTab({required this.kind});
  final MediaKind kind;

  @override
  ConsumerState<_KindTab> createState() => _KindTabState();
}

class _KindTabState extends ConsumerState<_KindTab> {
  _View _view = _View.toWatch;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(mediaProvider);
    final kind = widget.kind;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Adicionar ${kind.label.toLowerCase()}',
        onPressed: () => openMediaForm(context, ref, kind),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar ${kind.plural.toLowerCase()}',
            onChanged: (v) => setState(() => _query = v),
          ),
          FilterBar<_View>(
            options: [for (final v in _View.values) (v, v.label)],
            selected: _view,
            onSelected: (v) => setState(() => _view = v),
          ),
          Expanded(
            child: all.view((items) {
              final ofKind = [
                for (final m in items)
                  if (m.kind == kind &&
                      matchesQuery(_query, [m.title, m.notes]))
                    m,
              ];
              final list = switch (_view) {
                _View.toWatch => ofKind.where((m) => !m.watched).toList(),
                _View.watched => ofKind.where((m) => m.watched).toList(),
                _View.ranking => rankWatched(ofKind, mediaEntry),
              };
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.movie_outlined,
                  title: switch (_view) {
                    _View.toWatch => 'Nada na lista para assistir',
                    _View.watched => 'Nada assistido ainda',
                    _View.ranking => 'Ranking vazio',
                  },
                  message: _view == _View.ranking
                      ? 'O ranking mostra só os assistidos que têm nota.'
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _MediaCard(
                  item: list[i],
                  position: _view == _View.ranking ? i + 1 : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

Future<void> openMediaForm(
  BuildContext context,
  WidgetRef ref,
  MediaKind kind, [
  MediaItem? m,
]) async {
  final r = await showQuickForm(
    context,
    title: m == null ? 'Adicionar ${kind.label.toLowerCase()}' : 'Editar',
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
      NumberSpec(
        'rating',
        'Nota de 0 a 10 (opcional)',
        initial: m?.rating,
        min: 0,
        max: 10,
      ),
      if (kind.hasEpisodes) ...[
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
      message: '"${m!.title}" será removido da lista.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.delete(m.id);
    return;
  }
  await repo.save(
    id: m?.id,
    kind: kind,
    title: r.text('title'),
    rating: r.number('rating'),
    season: kind.hasEpisodes ? r.integer('season') : null,
    episode: kind.hasEpisodes ? r.integer('episode') : null,
    totalEpisodes: kind.hasEpisodes ? r.integer('total') : null,
    notes: r.textOrNull('notes'),
  );
}

class _MediaCard extends ConsumerWidget {
  const _MediaCard({required this.item, this.position});

  final MediaItem item;
  final int? position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = item;
    final repo = ref.read(mediaRepositoryProvider);
    final progress = episodeProgress(m.episode, m.totalEpisodes);
    final episodeText =
        m.kind.hasEpisodes && (m.season != null || m.episode != null)
        ? 'T${m.season ?? 1} · E${m.episode ?? 0}'
              '${m.totalEpisodes == null ? '' : ' de ${m.totalEpisodes}'}'
        : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMediaForm(context, ref, m.kind, m),
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
                    style: const TextStyle(
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
              if (m.kind.hasEpisodes && !m.watched)
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
  MediaKind? _kind;
  MediaItem? _picked;
  bool _empty = false;

  void _draw(List<MediaItem> items) {
    final next = drawUnwatched(
      items,
      mediaEntry,
      kind: _kind,
      avoidId: _picked?.id,
    );
    setState(() {
      _picked = next;
      _empty = next == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(mediaProvider).value ?? const <MediaItem>[];
    return Padding(
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
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _kind == null,
                onSelected: (_) => setState(() => _kind = null),
              ),
              for (final k in MediaKind.values)
                ChoiceChip(
                  label: Text(k.plural),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
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
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _picked!.kind.label,
                        style: const TextStyle(color: AppColors.primary),
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
