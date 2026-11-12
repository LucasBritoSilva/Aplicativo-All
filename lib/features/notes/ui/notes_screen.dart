import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/text.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../voice/ui/voice_capture_screen.dart';
import '../data/notes_repository.dart';
import 'note_editor_screen.dart';

enum _NoteFilter {
  all('Todas'),
  pinned('Fixadas'),
  voice('Por voz');

  const _NoteFilter(this.label);
  final String label;
}

/// Notas e ideias por voz, em um só módulo.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _query = '';
  _NoteFilter _filter = _NoteFilter.all;

  bool _matches(Note n) =>
      (_filter == _NoteFilter.all ||
          (_filter == _NoteFilter.pinned && n.pinned) ||
          (_filter == _NoteFilter.voice && n.fromVoice)) &&
      matchesQuery(_query, [n.title, n.body]);

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas e ideias'),
        actions: [
          IconButton(
            tooltip: 'Capturar ideia por voz',
            icon: const Icon(Icons.mic_none),
            onPressed: () => openVoiceCapture(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova anotação',
        onPressed: () => openNoteEditor(context),
        child: const Icon(Icons.edit_outlined),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar nas notas',
            onChanged: (v) => setState(() => _query = v),
          ),
          FilterBar<_NoteFilter>(
            options: [for (final f in _NoteFilter.values) (f, f.label)],
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: notes.view((all) {
              if (all.isEmpty) {
                return const EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'Nenhuma anotação',
                  message:
                      'Toque no lápis para escrever, ou no microfone para '
                      'capturar uma ideia por voz.',
                );
              }
              final list = all.where(_matches).toList();
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  title: 'Nada encontrado',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _NoteCard(note: list[i], today: today),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.today});

  final Note note;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updated = note.updatedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openNoteEditor(context, note: note),
        onLongPress: () => ref
            .read(notesRepositoryProvider)
            .setPinned(note.id, !note.pinned),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title != null) ...[
                Text(
                  note.title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
              ],
              if (note.body.isNotEmpty)
                Text(
                  note.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: note.title == null
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (note.pinned) ...[
                    const Icon(
                      Icons.push_pin,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (note.fromVoice) ...[
                    const Icon(Icons.mic, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    '${friendlyDay(updated, today)} · ${formatTime(updated)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textFaint,
                    ),
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
