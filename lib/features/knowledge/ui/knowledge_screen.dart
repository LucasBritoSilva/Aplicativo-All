import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../data/knowledge_repository.dart';

/// Conhecimentos e assuntos, com domínio de 1 a 5 estrelas.
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  String _query = '';
  KnowledgeSort _sort = KnowledgeSort.name;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(knowledgeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conhecimentos'),
        actions: [
          PopupMenuButton<KnowledgeSort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in KnowledgeSort.values)
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo conhecimento',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar conhecimentos',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: items.view((all) {
              final categories = {
                for (final k in all)
                  if (k.category != null) k.category!,
              }.toList()..sort();
              final shown = sortKnowledge([
                for (final k in all)
                  if ((_category == null || k.category == _category) &&
                      matchesQuery(_query, [k.title, k.description, k.category]))
                    k,
              ], _sort);
              return Column(
                children: [
                  if (categories.isNotEmpty)
                    FilterBar<String?>(
                      options: [
                        (null, 'Todas'),
                        for (final c in categories) (c, c),
                      ],
                      selected: _category,
                      onSelected: (c) => setState(() => _category = c),
                    ),
                  Expanded(
                    child: shown.isEmpty
                        ? EmptyState(
                            icon: Icons.psychology_outlined,
                            title: all.isEmpty
                                ? 'Nenhum conhecimento cadastrado'
                                : 'Nada encontrado',
                            message: all.isEmpty
                                ? 'Cadastre assuntos que você estuda ou domina '
                                      'e avalie o domínio de 1 a 5 estrelas.'
                                : null,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _KnowledgeCard(
                              item: shown[i],
                              onTap: () => _openForm(context, shown[i]),
                            ),
                          ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, [KnowledgeItem? item]) {
    showFormSheet<void>(
      context,
      title: item == null ? 'Novo conhecimento' : 'Editar conhecimento',
      builder: (_) => _KnowledgeForm(item: item),
    );
  }
}

class _KnowledgeCard extends ConsumerWidget {
  const _KnowledgeCard({required this.item, required this.onTap});

  final KnowledgeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (item.category != null) Pill(item.category!),
                ],
              ),
              if (item.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  StarRating(
                    value: item.stars,
                    size: 26,
                    onChanged: (v) => ref
                        .read(knowledgeRepositoryProvider)
                        .setStars(item.id, v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.stars == null ? 'Sem avaliação' : '${item.stars}/5',
                    style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnowledgeForm extends ConsumerStatefulWidget {
  const _KnowledgeForm({this.item});
  final KnowledgeItem? item;

  @override
  ConsumerState<_KnowledgeForm> createState() => _KnowledgeFormState();
}

class _KnowledgeFormState extends ConsumerState<_KnowledgeForm> {
  late final _title = TextEditingController(text: widget.item?.title);
  late final _description = TextEditingController(text: widget.item?.description);
  late final _category = TextEditingController(text: widget.item?.category);
  late int? _stars = widget.item?.stars;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Digite o nome do conhecimento.');
      return;
    }
    await ref
        .read(knowledgeRepositoryProvider)
        .save(
          id: widget.item?.id,
          title: title,
          description: _clean(_description),
          category: _clean(_category),
          stars: _stars,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir conhecimento',
      message: '"${widget.item!.title}" será apagado.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(knowledgeRepositoryProvider).delete(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Conhecimento ou assunto'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _category,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Categoria (opcional, ex.: Programação)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descrição e observações'),
        ),
        const SizedBox(height: 16),
        const Text('Domínio', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Row(
          children: [
            StarRating(
              value: _stars,
              size: 36,
              onChanged: (v) => setState(() => _stars = v),
            ),
            const SizedBox(width: 8),
            Text(
              _stars == null ? 'Toque para avaliar' : '$_stars de 5',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
        if (widget.item != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _delete,
            child: const Text('Excluir conhecimento'),
          ),
        ],
      ],
    );
  }
}
