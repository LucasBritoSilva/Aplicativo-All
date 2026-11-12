import 'package:flutter/material.dart';

import '../../features/goals/ui/goals_screen.dart';
import '../../features/habits/ui/habits_screen.dart';
import '../../features/reminders/ui/reminders_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/shopping/ui/shopping_screen.dart';
import '../../features/voice/ui/voice_capture_screen.dart';
import '../theme/app_theme.dart';

/// Módulos que não cabem na barra inferior.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_Entry>[
      _Entry(
        Icons.shopping_cart_outlined,
        'Compras',
        'Lista por seção do mercado',
        () => const ShoppingScreen(),
      ),
      _Entry(
        Icons.notifications_none,
        'Lembretes',
        'Avisos com data e hora exatas',
        () => const RemindersScreen(),
      ),
      _Entry(
        Icons.repeat,
        'Hábitos',
        'Metas semanais e progresso da semana',
        () => const HabitsScreen(),
      ),
      _Entry(
        Icons.flag_outlined,
        'Metas',
        'Objetivos de longo prazo',
        () => const GoalsScreen(),
      ),
      _Entry(
        Icons.mic_none,
        'Ideia por voz',
        'Fale e salve como anotação',
        () => const VoiceCaptureScreen(),
      ),
      _Entry(
        Icons.settings_outlined,
        'Configurações',
        'Backup no Google Drive e permissões',
        () => const SettingsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = entries[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(e.icon, color: AppColors.primary, size: 22),
              ),
              title: Text(e.title),
              subtitle: Text(
                e.subtitle,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => e.build())),
            ),
          );
        },
      ),
    );
  }
}

class _Entry {
  const _Entry(this.icon, this.title, this.subtitle, this.build);
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() build;
}
