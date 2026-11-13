import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// Mostra carregamento, erro ou o conteúdo de um valor assíncrono.
extension AsyncValueView<T> on AsyncValue<T> {
  Widget view(Widget Function(T data) builder) => when(
    loading: () => const Loading(),
    error: (e, _) => ErrorText(e),
    data: builder,
  );
}

/// Avaliação de 1 a 5 estrelas. Tocar na estrela já marcada limpa a nota.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 28,
  });

  final int? value;
  final ValueChanged<int?>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final current = value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: onChanged != null,
            label: '$i de 5 estrelas',
            selected: i <= current,
            child: InkResponse(
              radius: size * 0.7,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(current == i ? null : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  i <= current
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: size,
                  color: i <= current ? AppColors.primary : AppColors.textFaint,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Campo de busca usado no topo das listas.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Buscar'});

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
      ),
    );
  }
}

/// Fileira de filtros (chips) com rolagem horizontal.
class FilterBar<T> extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// Cada opção é (valor, texto mostrado).
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = options[i];
          return Center(
            child: ChoiceChip(
              label: Text(label),
              selected: value == selected,
              onSelected: (_) => onSelected(value),
            ),
          );
        },
      ),
    );
  }
}

/// Número grande com legenda, usado em resumos e estatísticas.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Cartão com vários [StatTile] lado a lado.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final t in tiles) Expanded(child: t)],
        ),
      ),
    );
  }
}

/// Menu de três pontos com "Editar" e "Excluir".
class EditDeleteMenu extends StatelessWidget {
  const EditDeleteMenu({super.key, this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Mais opções',
      onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete?.call(),
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Excluir')),
      ],
    );
  }
}
