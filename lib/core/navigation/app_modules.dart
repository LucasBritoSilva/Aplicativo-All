import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/app_limits/ui/app_limits_screen.dart';
import '../../features/bible/ui/bible_screen.dart';
import '../../features/break_timer/ui/break_timer_screen.dart';
import '../../features/challenges/ui/challenges_screen.dart';
import '../../features/college/ui/exams_screen.dart';
import '../../features/college/ui/grades_screen.dart';
import '../../features/contacts/ui/contacts_screen.dart';
import '../../features/counters/ui/counters_screen.dart';
import '../../features/decider/ui/decider_screen.dart';
import '../../features/events/ui/events_screen.dart';
import '../../features/goals/ui/goals_screen.dart';
import '../../features/gym/ui/gym_screen.dart';
import '../../features/habits/ui/habits_screen.dart';
import '../../features/knowledge/ui/knowledge_screen.dart';
import '../../features/media/ui/media_screen.dart';
import '../../features/notes/ui/notes_screen.dart';
import '../../features/priorities/ui/priorities_screen.dart';
import '../../features/projects/ui/projects_screen.dart';
import '../../features/reminders/ui/reminders_screen.dart';
import '../../features/routine/ui/routine_screen.dart';
import '../../features/shopping/ui/shopping_wishes_screen.dart';
import '../../features/stats/ui/stats_screen.dart';
import '../../features/tasks/ui/tasks_screen.dart';
import '../../features/vault/ui/vault_screen.dart';
import 'recent_modules.dart';

/// As seis categorias do menu lateral.
enum ModuleCategory {
  organizacao('Organização pessoal', Icons.event_available_outlined),
  anotacoes('Anotações e desenvolvimento', Icons.lightbulb_outline),
  vidaPessoal('Compras e vida pessoal', Icons.shopping_bag_outlined),
  faculdade('Faculdade', Icons.school_outlined),
  saude('Saúde e entretenimento', Icons.favorite_outline),
  ferramentas('Ferramentas e análise', Icons.insights);

  const ModuleCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Um módulo do app: uma entrada do menu que abre uma tela.
class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    required this.builder,
    this.shortTitle,
    this.confirmed = true,
  });

  /// Identificador estável, gravado no histórico de recentes. Não mude.
  final String id;
  final String title;

  /// Nome curto para os atalhos da tela inicial.
  final String? shortTitle;
  final IconData icon;
  final ModuleCategory category;
  final WidgetBuilder builder;

  /// Verdadeiro para os 21 módulos do escopo confirmado. Falso para os
  /// módulos que já existiam no app original e foram mantidos.
  final bool confirmed;

  String get tileTitle => shortTitle ?? title;
}

/// Todos os módulos, na ordem do menu.
final List<AppModule> appModules = [
  // Categoria 1 - Organização pessoal
  AppModule(
    id: 'tarefas',
    title: 'Tarefas',
    icon: Icons.check_circle_outline,
    category: ModuleCategory.organizacao,
    builder: (_) => const TasksScreen(),
  ),
  AppModule(
    id: 'rotina',
    title: 'Rotina',
    icon: Icons.wb_sunny_outlined,
    category: ModuleCategory.organizacao,
    builder: (_) => const RoutineScreen(),
  ),
  AppModule(
    id: 'prioridades',
    title: 'Prioridades diárias',
    shortTitle: 'Prioridades',
    icon: Icons.flag_outlined,
    category: ModuleCategory.organizacao,
    builder: (_) => const PrioritiesScreen(),
  ),
  AppModule(
    id: 'contador',
    title: 'Contador de dias',
    shortTitle: 'Contador',
    icon: Icons.hourglass_bottom,
    category: ModuleCategory.organizacao,
    builder: (_) => const CountersScreen(),
  ),
  AppModule(
    id: 'desafios',
    title: 'Desafios pessoais',
    shortTitle: 'Desafios',
    icon: Icons.emoji_events_outlined,
    category: ModuleCategory.organizacao,
    builder: (_) => const ChallengesScreen(),
  ),
  AppModule(
    id: 'pausas',
    title: 'Pausas para descanso',
    shortTitle: 'Pausas',
    icon: Icons.coffee_outlined,
    category: ModuleCategory.organizacao,
    builder: (_) => const BreakTimerScreen(),
  ),
  AppModule(
    id: 'lembretes',
    title: 'Lembretes',
    icon: Icons.notifications_none,
    category: ModuleCategory.organizacao,
    builder: (_) => const RemindersScreen(),
    confirmed: false,
  ),
  AppModule(
    id: 'habitos',
    title: 'Hábitos',
    icon: Icons.repeat,
    category: ModuleCategory.organizacao,
    builder: (_) => const HabitsScreen(),
    confirmed: false,
  ),
  AppModule(
    id: 'metas',
    title: 'Metas',
    icon: Icons.track_changes,
    category: ModuleCategory.organizacao,
    builder: (_) => const GoalsScreen(),
    confirmed: false,
  ),

  // Categoria 2 - Anotações e desenvolvimento
  AppModule(
    id: 'notas',
    title: 'Notas e ideias por voz',
    shortTitle: 'Notas',
    icon: Icons.sticky_note_2_outlined,
    category: ModuleCategory.anotacoes,
    builder: (_) => const NotesScreen(),
  ),
  AppModule(
    id: 'conhecimentos',
    title: 'Conhecimentos',
    icon: Icons.psychology_outlined,
    category: ModuleCategory.anotacoes,
    builder: (_) => const KnowledgeScreen(),
  ),
  AppModule(
    id: 'projetos',
    title: 'Ideias de projetos',
    shortTitle: 'Projetos',
    icon: Icons.lightbulb_outline,
    category: ModuleCategory.anotacoes,
    builder: (_) => const ProjectsScreen(),
  ),

  // Categoria 3 - Compras e vida pessoal
  AppModule(
    id: 'compras',
    title: 'Lista de compras e desejos',
    shortTitle: 'Compras',
    icon: Icons.shopping_cart_outlined,
    category: ModuleCategory.vidaPessoal,
    builder: (_) => const ShoppingWishesScreen(),
  ),
  AppModule(
    id: 'contatos',
    title: 'Contatos úteis',
    shortTitle: 'Contatos',
    icon: Icons.contact_phone_outlined,
    category: ModuleCategory.vidaPessoal,
    builder: (_) => const ContactsScreen(),
  ),
  AppModule(
    id: 'cofre',
    title: 'Cofre de informações',
    shortTitle: 'Cofre',
    icon: Icons.lock_outline,
    category: ModuleCategory.vidaPessoal,
    builder: (_) => const VaultScreen(),
  ),
  AppModule(
    id: 'eventos',
    title: 'Eventos sociais',
    shortTitle: 'Eventos',
    icon: Icons.celebration_outlined,
    category: ModuleCategory.vidaPessoal,
    builder: (_) => const EventsScreen(),
  ),

  // Categoria 4 - Faculdade
  AppModule(
    id: 'notas_faculdade',
    title: 'Controle de notas',
    shortTitle: 'Notas da faculdade',
    icon: Icons.grade_outlined,
    category: ModuleCategory.faculdade,
    builder: (_) => const GradesScreen(),
  ),
  AppModule(
    id: 'provas',
    title: 'Controle de provas',
    shortTitle: 'Provas',
    icon: Icons.assignment_outlined,
    category: ModuleCategory.faculdade,
    builder: (_) => const ExamsScreen(),
  ),

  // Categoria 5 - Saúde e entretenimento
  AppModule(
    id: 'academia',
    title: 'Academia',
    icon: Icons.fitness_center,
    category: ModuleCategory.saude,
    builder: (_) => const GymScreen(),
  ),
  AppModule(
    id: 'midia',
    title: 'Filmes, séries e animes',
    shortTitle: 'Filmes e séries',
    icon: Icons.movie_outlined,
    category: ModuleCategory.saude,
    builder: (_) => const MediaScreen(),
  ),
  AppModule(
    id: 'biblia',
    title: 'Leitura da Bíblia',
    shortTitle: 'Bíblia',
    icon: Icons.menu_book_outlined,
    category: ModuleCategory.saude,
    builder: (_) => const BibleScreen(),
  ),

  // Categoria 6 - Ferramentas e análise
  AppModule(
    id: 'decisor',
    title: 'Decisor aleatório',
    shortTitle: 'Decisor',
    icon: Icons.casino_outlined,
    category: ModuleCategory.ferramentas,
    builder: (_) => const DeciderScreen(),
  ),
  AppModule(
    id: 'limite_apps',
    title: 'Limite de uso de aplicativos',
    shortTitle: 'Limite de apps',
    icon: Icons.timelapse,
    category: ModuleCategory.ferramentas,
    builder: (_) => const AppLimitsScreen(),
  ),
  AppModule(
    id: 'estatisticas',
    title: 'Estatísticas pessoais',
    shortTitle: 'Estatísticas',
    icon: Icons.insights,
    category: ModuleCategory.ferramentas,
    builder: (_) => const StatsScreen(),
  ),
];

/// Atalhos sugeridos na tela inicial enquanto não há histórico.
const defaultModuleSuggestions = [
  'rotina',
  'tarefas',
  'prioridades',
  'notas',
  'compras',
  'academia',
];

AppModule? moduleById(String id) {
  for (final m in appModules) {
    if (m.id == id) return m;
  }
  return null;
}

List<AppModule> modulesOf(ModuleCategory category) =>
    appModules.where((m) => m.category == category).toList();

/// Abre um módulo e registra o acesso para a grade de recentes.
Future<void> openModule(
  NavigatorState navigator,
  WidgetRef ref,
  AppModule module,
) {
  ref.read(recentModulesProvider.notifier).registerAccess(module.id);
  return navigator.push(
    MaterialPageRoute<void>(
      builder: module.builder,
      settings: RouteSettings(name: module.id),
    ),
  );
}
