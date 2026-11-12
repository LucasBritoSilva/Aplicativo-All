import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agenda/ui/agenda_screen.dart';
import '../../features/notes/ui/notes_screen.dart';
import '../../features/routine/data/routine_repository.dart';
import '../../features/routine/ui/routine_screen.dart';
import '../../features/tasks/ui/tasks_screen.dart';
import '../utils/today_provider.dart';
import 'more_screen.dart';

/// Tela principal com a barra inferior (no máximo 5 destinos).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Virou o dia: zera a rotina diária.
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != next) {
        ref.read(routineRepositoryProvider).resetStale(next);
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AgendaScreen(),
          TasksScreen(),
          RoutineScreen(),
          NotesScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tarefas',
          ),
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Rotina',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: 'Notas',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}
