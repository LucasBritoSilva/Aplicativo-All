import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/notes_repository.dart';

void openNoteEditor(BuildContext context, {Note? note}) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(note: note)));
}

/// Imagem de uma nota guardada na pasta privada do app.
class NoteImageView extends StatelessWidget {
  const NoteImageView(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final String path;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.surfaceHigh,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textFaint,
        ),
      ),
    );
  }
}

/// Editor de anotação: título opcional, texto livre e imagens anexadas.
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
  late final NotesRepository _repo = ref.read(notesRepositoryProvider);
  bool _deleted = false;
  late bool _pinned = widget.note?.pinned ?? false;

  /// Imagens na ordem em que aparecem na nota.
  List<String> _images = [];

  /// Imagens que já estavam gravadas quando o editor abriu.
  List<String> _savedImages = [];

  /// Arquivos escolhidos agora (apagados se a nota não for salva).
  final _picked = <String>{};
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      _repo.imagesOf(note.id).then((imgs) {
        if (!mounted) return;
        setState(() {
          _savedImages = [for (final i in imgs) i.path];
          _images = [..._savedImages];
        });
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _imagesChanged =>
      _images.length != _savedImages.length ||
      [for (var i = 0; i < _images.length; i++) _images[i] != _savedImages[i]]
          .any((x) => x);

  bool get _changed =>
      _title.text.trim() != (widget.note?.title ?? '') ||
      _body.text != (widget.note?.body ?? '') ||
      _imagesChanged;

  /// Salva se houver algo novo. Anotação nova e vazia é descartada.
  Future<void> _saveIfNeeded() async {
    if (_deleted) return;
    final unused = _picked.where((p) => !_images.contains(p)).toList();
    if (!_changed) {
      await _repo.discardFiles(unused);
      return;
    }
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty && _images.isEmpty) {
      await _repo.discardFiles(_picked.toList());
      return;
    }
    final id = await _repo.save(id: widget.note?.id, title: title, body: body);
    if (_imagesChanged) await _repo.setImages(id, _images);
    await _repo.discardFiles(unused);
  }

  Future<void> _attach() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final paths = await ref.read(nativeBridgeProvider).pickImages();
      if (!mounted) return;
      setState(() {
        _picked.addAll(paths);
        _images = [..._images, ...paths];
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _remove(String path) => setState(
    () => _images = [
      for (final p in _images)
        if (p != path) p,
    ],
  );

  Future<void> _view(String path) async {
    final remove = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => _ImageViewer(path: path)));
    if (remove == true) _remove(path);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir anotação',
      message: 'Esta anotação e as imagens dela serão apagadas.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    _deleted = true;
    await _repo.delete(widget.note!.id);
    await _repo.discardFiles(_picked.toList());
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
            IconButton(
              tooltip: 'Anexar imagem',
              icon: _picking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _picking ? null : _attach,
            ),
            if (widget.note != null)
              IconButton(
                tooltip: _pinned ? 'Desafixar' : 'Fixar no topo',
                icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: () {
                  setState(() => _pinned = !_pinned);
                  _repo.setPinned(widget.note!.id, _pinned);
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
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final path = _images[i];
                      return Stack(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Imagem ${i + 1}, toque para ampliar',
                            child: InkWell(
                              onTap: () => _view(path),
                              borderRadius: BorderRadius.circular(12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: NoteImageView(path, cacheWidth: 300),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _remove(path),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                    semanticLabel: 'Remover imagem',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
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

/// Imagem em tela cheia, com zoom. Devolve true se for para remover.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover da nota'),
          ),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: NoteImageView(path, fit: BoxFit.contain)),
      ),
    );
  }
}
