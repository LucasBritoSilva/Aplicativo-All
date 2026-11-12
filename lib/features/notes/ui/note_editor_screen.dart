import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/notes_repository.dart';

void openNoteEditor(BuildContext context, {Note? note}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(note: note)),
  );
}

/// Editor de anotação: título opcional e texto livre.
/// Salva automaticamente ao voltar.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note});
  final Note? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  bool _deleted = false;
  late bool _pinned = widget.note?.pinned ?? false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _changed =>
      _title.text.trim() != (widget.note?.title ?? '') ||
      _body.text != (widget.note?.body ?? '');

  /// Salva se houver algo novo. Anotação nova e vazia é descartada.
  Future<void> _saveIfNeeded() async {
    if (_deleted || !_changed) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) return;
    await ref
        .read(notesRepositoryProvider)
        .save(id: widget.note?.id, title: title, body: body);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir anotação',
      message: 'Esta anotação será apagada.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    _deleted = true;
    await ref.read(notesRepositoryProvider).delete(widget.note!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveIfNeeded();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'Nova anotação' : 'Anotação'),
          actions: [
            if (widget.note != null)
              IconButton(
                tooltip: _pinned ? 'Desafixar' : 'Fixar no topo',
                icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: () {
                  setState(() => _pinned = !_pinned);
                  ref
                      .read(notesRepositoryProvider)
                      .setPinned(widget.note!.id, _pinned);
                },
              ),
            if (widget.note != null)
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            IconButton(
              tooltip: 'Salvar',
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'Título (opcional)',
                  filled: false,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: _body,
                  autofocus: widget.note == null,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Escreva aqui...',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    filled: false,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
