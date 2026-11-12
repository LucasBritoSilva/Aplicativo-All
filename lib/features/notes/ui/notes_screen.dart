import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/today_provider.dart';
import '../../../core/widgets/common.dart';
import '../../voice/ui/voice_capture_screen.dart';
import '../data/notes_repository.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
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
      body: notes.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorText(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'Nenhuma anotação',
              message:
                  'Toque no lápis para escrever, ou no microfone para '
                  'capturar uma ideia por voz.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _NoteCard(note: list[i], today: today),
          );
        },
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.today});

  final Note note;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final updated = note.updatedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openNoteEditor(context, note: note),
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
