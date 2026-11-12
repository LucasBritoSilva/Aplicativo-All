import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/wishes_repository.dart';

/// Aba "Desejos": produtos com link opcional, organizados em pastas.
class WishesTab extends ConsumerWidget {
  const WishesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(wishesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo desejo',
        heroTag: null,
        onPressed: () =>
            openWishForm(context, ref, data.value?.folders ?? const []),
        child: const Icon(Icons.add),
      ),
      body: data.view((d) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _newFolder(context, ref),
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                    label: const Text('Nova pasta'),
                  ),
                ],
              ),
            ),
            if (d.items.isEmpty && d.folders.isEmpty)
              const EmptyState(
                icon: Icons.card_giftcard,
                title: 'Lista de desejos vazia',
                message:
                    'Guarde produtos que você quer comprar um dia, com link, '
                    'e organize em pastas como "Casa" ou "Tecnologia".',
              ),
            for (final f in d.folders)
              _FolderSection(
                folder: f,
                items: d.itemsIn(f.id),
                folders: d.folders,
              ),
            if (d.itemsIn(null).isNotEmpty || d.folders.isEmpty)
              _FolderSection(
                folder: null,
                items: d.itemsIn(null),
                folders: d.folders,
              ),
          ],
        );
      }),
    );
  }

  Future<void> _newFolder(BuildContext context, WidgetRef ref) async {
    final r = await showQuickForm(
      context,
      title: 'Nova pasta',
      fields: const [
        TextSpec('name', 'Nome da pasta', required: true, autofocus: true),
      ],
    );
    if (r != null) {
      await ref.read(wishesRepositoryProvider).createFolder(r.text('name'));
    }
  }
}

Future<void> openWishForm(
  BuildContext context,
  WidgetRef ref,
  List<WishFolder> folders, {
  WishItem? item,
  int? folderId,
}) async {
  final r = await showQuickForm(
    context,
    title: item == null ? 'Novo desejo' : 'Editar desejo',
    deleteLabel: item == null ? null : 'Excluir desejo',
    fields: [
      TextSpec(
        'name',
        'Produto',
        initial: item?.name,
        required: true,
        autofocus: item == null,
      ),
      TextSpec(
        'link',
        'Link (opcional)',
        initial: item?.link,
        keyboard: TextInputType.url,
        capitalization: TextCapitalization.none,
      ),
      NumberSpec(
        'price',
        'Preço estimado (opcional)',
        initial: item?.price,
        min: 0,
        suffix: 'R\$',
      ),
      ChoiceSpec<int?>(
        'folder',
        'Pasta',
        options: [(null, 'Sem pasta'), for (final f in folders) (f.id, f.name)],
        initial: item?.folderId ?? folderId,
      ),
      TextSpec('notes', 'Observações', initial: item?.notes, lines: 3),
    ],
  );
  if (r == null || !context.mounted) return;
  final repo = ref.read(wishesRepositoryProvider);
  if (r.deleted) {
    final ok = await confirm(
      context,
      title: 'Excluir desejo',
      message: '"${item!.name}" será apagado.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) await repo.deleteItem(item.id);
    return;
  }
  await repo.saveItem(
    id: item?.id,
    name: r.text('name'),
    link: normalizeLink(r.textOrNull('link')),
    price: r.number('price'),
    notes: r.textOrNull('notes'),
    folderId: r.choice<int?>('folder'),
  );
}

class _FolderSection extends ConsumerWidget {
  const _FolderSection({
    required this.folder,
    required this.items,
    required this.folders,
  });

  final WishFolder? folder;
  final List<WishItem> items;
  final List<WishFolder> folders;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final r = await showQuickForm(
      context,
      title: 'Renomear pasta',
      fields: [
        TextSpec(
          'name',
          'Nome da pasta',
          initial: folder!.name,
          required: true,
        ),
      ],
    );
    if (r != null) {
      await ref
          .read(wishesRepositoryProvider)
          .renameFolder(folder!.id, r.text('name'));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(wishesRepositoryProvider);
    if (items.isEmpty) {
      final ok = await confirm(
        context,
        title: 'Excluir pasta',
        message: 'A pasta "${folder!.name}" está vazia e será excluída.',
        confirmLabel: 'Excluir',
        destructive: true,
      );
      if (ok) await repo.deleteFolder(folder!.id);
      return;
    }
    // Pasta com itens: o usuário escolhe para onde eles vão.
    final others = folders.where((f) => f.id != folder!.id).toList();
    final r = await showQuickForm(
      context,
      title: 'Excluir a pasta "${folder!.name}"',
      submitLabel: 'Mover itens e excluir pasta',
      fields: [
        ChoiceSpec<int?>(
          'target',
          'Para onde vão os ${items.length} itens?',
          options: [
            (null, 'Sem pasta'),
            for (final f in others) (f.id, f.name),
          ],
          initial: null,
        ),
      ],
    );
    if (r == null) return;
    await repo.deleteFolder(folder!.id, moveTo: r.choice<int?>('target'));
    if (context.mounted) {
      showMessage(context, 'Pasta excluída. Nenhum item foi perdido.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = folder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          f?.name ?? 'Sem pasta',
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 6),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${items.length}',
                style: const TextStyle(color: AppColors.textFaint),
              ),
              IconButton(
                tooltip: 'Adicionar nesta pasta',
                icon: const Icon(Icons.add, size: 20),
                onPressed: () =>
                    openWishForm(context, ref, folders, folderId: f?.id),
              ),
              if (f != null)
                PopupMenuButton<String>(
                  tooltip: 'Opções da pasta',
                  onSelected: (v) => v == 'rename'
                      ? _rename(context, ref)
                      : _delete(context, ref),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renomear')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir pasta'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Nenhum item',
              style: TextStyle(color: AppColors.textFaint),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  for (final i in items) _WishTile(item: i, folders: folders),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WishTile extends ConsumerWidget {
  const _WishTile({required this.item, required this.folders});

  final WishItem item;
  final List<WishFolder> folders;

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final r = await showQuickForm(
      context,
      title: 'Mover "${item.name}"',
      submitLabel: 'Mover',
      fields: [
        ChoiceSpec<int?>(
          'folder',
          'Pasta',
          options: [
            (null, 'Sem pasta'),
            for (final f in folders) (f.id, f.name),
          ],
          initial: item.folderId,
        ),
      ],
    );
    if (r != null) {
      await ref
          .read(wishesRepositoryProvider)
          .moveItem(item.id, r.choice<int?>('folder'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(wishesRepositoryProvider);
    final details = [
      if (item.price != null) 'R\$ ${formatNumber(item.price!)}',
      if (item.notes != null) item.notes!,
    ].join(' · ');
    return ListTile(
      onTap: () => openWishForm(context, ref, folders, item: item),
      leading: Checkbox(
        value: item.acquired,
        onChanged: (v) => repo.setAcquired(item.id, v ?? false),
      ),
      title: Text(
        item.name,
        style: item.acquired
            ? const TextStyle(
                color: AppColors.textFaint,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.link != null)
            IconButton(
              tooltip: 'Abrir link',
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: () async {
                final ok = await ref
                    .read(nativeBridgeProvider)
                    .openUrl(item.link!);
                if (!ok && context.mounted) {
                  showMessage(context, 'Nenhum app conseguiu abrir este link.');
                }
              },
            ),
          IconButton(
            tooltip: 'Mover para outra pasta',
            icon: const Icon(Icons.drive_file_move_outline, size: 20),
            onPressed: () => _move(context, ref),
          ),
        ],
      ),
    );
  }
}
