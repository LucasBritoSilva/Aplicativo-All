import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/shopping_repository.dart';
import '../domain/shopping_section.dart';

/// Aba "Mercado": itens por seção do mercado, marcados como comprados.
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(shoppingItemsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar item',
        heroTag: null,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Lista vazia',
              message: 'Toque em + para adicionar um item.',
            );
          }
          final bought = list.where((i) => i.bought).length;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$bought de ${list.length} no carrinho',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    if (bought > 0)
                      TextButton.icon(
                        onPressed: () => _clearBought(context, ref),
                        icon: const Icon(Icons.remove_done, size: 18),
                        label: const Text('Limpar comprados'),
                      ),
                  ],
                ),
              ),
              for (final section in ShoppingSection.values)
                ..._section(context, ref, section, list),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    ShoppingSection section,
    List<ShoppingItem> all,
  ) {
    final items = all.where((i) => i.section == section).toList();
    if (items.isEmpty) return const [];
    final pending = items.where((i) => !i.bought).length;
    return [
      SectionLabel(
        section.label,
        trailing: Text(
          pending == 0 ? 'ok' : '$pending',
          style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Column(
            children: [
              for (final item in items)
                _ShoppingTile(
                  item: item,
                  onToggle: () => ref
                      .read(shoppingRepositoryProvider)
                      .setBought(item.id, !item.bought),
                  onEdit: () => _openForm(context, item: item),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Future<void> _clearBought(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Limpar comprados',
      message: 'Remover da lista todos os itens já marcados como comprados?',
      confirmLabel: 'Remover',
      destructive: true,
    );
    if (ok) await ref.read(shoppingRepositoryProvider).clearBought();
  }

  void _openForm(BuildContext context, {ShoppingItem? item}) {
    showFormSheet<void>(
      context,
      title: item == null ? 'Novo item' : 'Editar item',
      builder: (_) => _ShoppingForm(item: item),
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  const _ShoppingTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final style = item.bought
        ? const TextStyle(
            color: AppColors.textFaint,
            decoration: TextDecoration.lineThrough,
          )
        : null;
    return ListTile(
      onTap: onToggle,
      leading: Checkbox(value: item.bought, onChanged: (_) => onToggle()),
      title: Text(item.name, style: style),
      subtitle: item.quantity == null
          ? null
          : Text(
              item.quantity!,
              style: const TextStyle(color: AppColors.textMuted),
            ),
      trailing: IconButton(
        tooltip: 'Editar',
        icon: const Icon(Icons.edit_outlined, size: 20),
        onPressed: onEdit,
      ),
    );
  }
}

class _ShoppingForm extends ConsumerStatefulWidget {
  const _ShoppingForm({this.item});
  final ShoppingItem? item;

  @override
  ConsumerState<_ShoppingForm> createState() => _ShoppingFormState();
}

class _ShoppingFormState extends ConsumerState<_ShoppingForm> {
  /// Lembra a última seção usada, para agilizar a digitação.
  static ShoppingSection _lastSection = ShoppingSection.hortifruti;

  late final _name = TextEditingController(text: widget.item?.name);
  late final _quantity = TextEditingController(text: widget.item?.quantity);
  late ShoppingSection _section = widget.item?.section ?? _lastSection;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Digite o nome do item.');
      return;
    }
    final qty = _quantity.text.trim();
    final repo = ref.read(shoppingRepositoryProvider);
    if (widget.item == null) {
      await repo.add(
        name: name,
        quantity: qty.isEmpty ? null : qty,
        section: _section,
      );
    } else {
      await repo.edit(
        widget.item!.id,
        name: name,
        quantity: qty.isEmpty ? null : qty,
        section: _section,
      );
    }
    _lastSection = _section;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir item',
      message: '"${widget.item!.name}" sairá da lista.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(shoppingRepositoryProvider).delete(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Item (ex.: tomate)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantity,
          decoration: const InputDecoration(
            hintText: 'Quantidade (opcional, ex.: 1 kg)',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ShoppingSection.values)
              ChoiceChip(
                avatar: Icon(s.icon, size: 16),
                label: Text(s.label),
                selected: _section == s,
                onSelected: (_) => setState(() => _section = s),
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
            child: const Text('Excluir item'),
          ),
        ],
      ],
    );
  }
}
