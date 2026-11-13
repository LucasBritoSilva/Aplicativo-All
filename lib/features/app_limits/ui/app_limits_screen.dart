import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../domain/app_limits_logic.dart';

class AppLimitsRepository {
  AppLimitsRepository(this._db, this._settings, this._native);

  final AppDatabase _db;
  final SettingsRepository _settings;
  final NativeBridge _native;

  Stream<List<AppLimit>> watchAll() =>
      (_db.select(_db.appLimits)..orderBy([
            (l) => OrderingTerm.asc(l.label.collate(Collate.noCase)),
          ]))
          .watch();

  Future<void> save({
    required String packageName,
    required String label,
    required int minutes,
    required LimitMode mode,
  }) => _db
      .into(_db.appLimits)
      .insertOnConflictUpdate(
        AppLimitsCompanion.insert(
          packageName: packageName,
          label: label,
          limitMinutes: minutes,
          mode: Value(mode),
        ),
      );

  Future<void> setEnabled(String packageName, bool enabled) =>
      (_db.update(_db.appLimits)
            ..where((l) => l.packageName.equals(packageName)))
          .write(AppLimitsCompanion(enabled: Value(enabled)));

  Future<void> delete(String packageName) => (_db.delete(
    _db.appLimits,
  )..where((l) => l.packageName.equals(packageName))).go();

  Future<bool> monitorWanted() async =>
      (await _settings.read(SettingKeys.appLimitsMonitor)) == 'on';

  /// Envia os limites atuais ao serviço nativo (liga, atualiza ou desliga).
  Future<bool> applyMonitor({bool? enabled}) async {
    final want = enabled ?? await monitorWanted();
    await _settings.write(SettingKeys.appLimitsMonitor, want ? 'on' : 'off');
    final limits = await _db.select(_db.appLimits).get();
    return _native.configureMonitor(
      enabled: want,
      limits: activeLimits([
        for (final l in limits)
          (
            packageName: l.packageName,
            limitMinutes: l.limitMinutes,
            enabled: l.enabled,
          ),
      ]),
      modes: activeModes([
        for (final l in limits)
          (
            packageName: l.packageName,
            limitMinutes: l.limitMinutes,
            enabled: l.enabled,
            mode: l.mode.name,
          ),
      ]),
    );
  }
}

final appLimitsRepositoryProvider = Provider<AppLimitsRepository>(
  (ref) => AppLimitsRepository(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(nativeBridgeProvider),
  ),
);

final appLimitsProvider = StreamProvider<List<AppLimit>>(
  (ref) => ref.watch(appLimitsRepositoryProvider).watchAll(),
);

/// Limite de uso de aplicativos: acompanhamento, sem bloqueio.
///
/// O tempo vem das estatísticas de uso do Android (permissão "Acesso ao
/// uso"). Cada app tem um modo: contador flutuante (permissão "Sobrepor a
/// outros apps") ou uma notificação ao atingir o limite (permissão de
/// notificações). Os dois usam um serviço com notificação fixa, que o
/// usuário liga e desliga aqui.
class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool? _usageAccess;
  bool? _overlay;
  bool? _notifications;
  bool _monitorWanted = false;
  bool _monitorRunning = false;
  Map<String, int> _usage = const {};

  NativeBridge get _native => ref.read(nativeBridgeProvider);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final usageAccess = await _native.hasUsageAccess();
    final overlay = await _native.canDrawOverlays();
    final notifications =
        await ref.read(permissionServiceProvider).notificationStatus() ==
        PermissionState.granted;
    final usage = usageAccess
        ? await _native.usageToday()
        : const <String, int>{};
    final wanted = await ref.read(appLimitsRepositoryProvider).monitorWanted();
    final running = await _native.monitorRunning();
    if (!mounted) return;
    setState(() {
      _usageAccess = usageAccess;
      _overlay = overlay;
      _notifications = notifications;
      _usage = usage;
      _monitorWanted = wanted;
      _monitorRunning = running;
    });
  }

  Future<void> _toggleMonitor(bool on) async {
    if (on && _usageAccess != true) {
      showMessage(context, 'Libere o "Acesso ao uso" para ligar o monitor.');
      return;
    }
    final limits = ref.read(appLimitsProvider).value ?? const <AppLimit>[];
    if (on &&
        _overlay != true &&
        limits.any((l) => l.enabled && l.mode == LimitMode.overlay)) {
      showMessage(
        context,
        'Libere "Sobrepor a outros apps" para os apps com contador flutuante.',
      );
    }
    if (on &&
        _notifications != true &&
        limits.any((l) => l.enabled && l.mode == LimitMode.notify)) {
      await ref.read(permissionServiceProvider).requestNotifications();
    }
    final ok = await ref
        .read(appLimitsRepositoryProvider)
        .applyMonitor(enabled: on);
    if (!ok && on && mounted) {
      showMessage(context, 'O Android não deixou iniciar o monitor agora.');
    }
    await _refresh();
  }

  Future<void> _addApp() async {
    final picked = await Navigator.of(context).push<InstalledApp>(
      MaterialPageRoute(builder: (_) => const _AppPickerScreen()),
    );
    if (picked == null || !mounted) return;
    await _editLimit(picked.packageName, picked.label, null);
  }

  Future<void> _editLimit(String pkg, String label, AppLimit? current) async {
    final r = await showQuickForm(
      context,
      title: label,
      deleteLabel: current == null ? null : 'Parar de monitorar',
      fields: [
        NumberSpec(
          'min',
          'Limite diário',
          initial: current?.limitMinutes.toDouble() ?? 30,
          required: true,
          decimal: false,
          min: 1,
          max: 1440,
          suffix: 'min',
        ),
        ChoiceSpec<LimitMode>(
          'mode',
          'Como acompanhar',
          options: [for (final m in LimitMode.values) (m, m.label)],
          initial: current?.mode ?? LimitMode.overlay,
        ),
      ],
    );
    if (r == null) return;
    final repo = ref.read(appLimitsRepositoryProvider);
    if (r.deleted) {
      await repo.delete(pkg);
    } else {
      final mode = r.choice<LimitMode>('mode');
      await repo.save(
        packageName: pkg,
        label: label,
        minutes: r.integer('min')!,
        mode: mode,
      );
      if (mode == LimitMode.notify && _notifications != true) {
        await ref.read(permissionServiceProvider).requestNotifications();
      }
    }
    await repo.applyMonitor();
    await _refresh();
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String why,
    required bool? granted,
    required VoidCallback onOpen,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(
      why,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
    trailing: granted == true
        ? const Icon(Icons.check, color: AppColors.success)
        : TextButton(onPressed: onOpen, child: const Text('Liberar')),
  );

  @override
  Widget build(BuildContext context) {
    final limits = ref.watch(appLimitsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limite de uso de apps'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _usageAccess == true ? _addApp : null,
        icon: const Icon(Icons.add),
        label: const Text('App'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Card(
            child: Column(
              children: [
                _permissionTile(
                  icon: Icons.query_stats,
                  title: 'Acesso ao uso',
                  why: 'Necessário para saber quanto tempo cada app foi usado hoje.',
                  granted: _usageAccess,
                  onOpen: _native.openUsageAccessSettings,
                ),
                _permissionTile(
                  icon: Icons.picture_in_picture_alt_outlined,
                  title: 'Sobrepor a outros apps',
                  why: 'Só para os apps no modo contador flutuante.',
                  granted: _overlay,
                  onOpen: _native.openOverlaySettings,
                ),
                _permissionTile(
                  icon: Icons.notifications_none,
                  title: 'Notificações',
                  why: 'Só para os apps no modo notificação ao atingir o limite.',
                  granted: _notifications,
                  onOpen: () async {
                    final perms = ref.read(permissionServiceProvider);
                    final r = await perms.requestNotifications();
                    if (r == PermissionState.blocked) {
                      await perms.openSettings();
                    }
                    await _refresh();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.timer_outlined),
                  title: const Text('Monitoramento ligado'),
                  subtitle: Text(
                    _monitorRunning
                        ? 'Ligado. Uma notificação fixa indica que ele está ativo.'
                        : (_monitorWanted
                              ? 'Desligado pelo Android. Toque para ligar de novo.'
                              : 'Acompanha os apps abaixo conforme o modo de cada um.'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  value: _monitorRunning,
                  onChanged: _toggleMonitor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'O app apenas acompanha e avisa: nenhum app é bloqueado. O tempo '
              'segue a contagem do próprio Android e zera à meia-noite. No modo '
              'notificação, o aviso chega uma vez por dia, enquanto você usa o '
              'app e o monitoramento está ligado. Alguns aparelhos encerram '
              'serviços para economizar bateria; nesse caso, abra o BrutAll '
              'para religar.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12),
            ),
          ),
          const SectionLabel(
            'Apps monitorados',
            padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
          ),
          limits.view((list) {
            if (_usageAccess == false) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Libere o "Acesso ao uso" para escolher apps e ver o tempo.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Nenhum app monitorado. Toque em "App" para escolher.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return Column(
              children: [
                for (final l in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LimitCard(
                      limit: l,
                      status: LimitStatus(
                        usedMs: _usage[l.packageName] ?? 0,
                        limitMinutes: l.limitMinutes,
                      ),
                      onTap: () => _editLimit(l.packageName, l.label, l),
                      onToggle: (v) async {
                        final repo = ref.read(appLimitsRepositoryProvider);
                        await repo.setEnabled(l.packageName, v);
                        await repo.applyMonitor();
                      },
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({
    required this.limit,
    required this.status,
    required this.onTap,
    required this.onToggle,
  });

  final AppLimit limit;
  final LimitStatus status;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final color = status.exceeded ? AppColors.danger : AppColors.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      limit.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Switch(value: limit.enabled, onChanged: onToggle),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Pill(
                  limit.mode.label,
                  icon: limit.mode == LimitMode.overlay
                      ? Icons.picture_in_picture_alt_outlined
                      : Icons.notifications_none,
                ),
              ),
              ProgressBar(value: status.fraction),
              const SizedBox(height: 8),
              Text(
                'Usado hoje: ${formatUsage(status.usedMs)} de ${formatUsage(status.limitMs)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              Text(
                status.exceeded
                    ? 'Limite atingido${status.overMs > 0 ? ' (+${formatUsage(status.overMs)})' : ''}'
                    : 'Restam ${formatUsage(status.remainingMs)}',
                style: TextStyle(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista dos apps instalados para escolher qual monitorar.
class _AppPickerScreen extends ConsumerStatefulWidget {
  const _AppPickerScreen();

  @override
  ConsumerState<_AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<_AppPickerScreen> {
  List<InstalledApp>? _apps;
  String _query = '';

  @override
  void initState() {
    super.initState();
    ref.read(nativeBridgeProvider).installedApps().then((apps) {
      if (mounted) setState(() => _apps = apps);
    });
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher app')),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar app',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: apps == null
                ? const Loading()
                : Builder(
                    builder: (context) {
                      final shown = [
                        for (final a in apps)
                          if (matchesQuery(_query, [a.label, a.packageName])) a,
                      ];
                      if (shown.isEmpty) {
                        return const EmptyState(
                          icon: Icons.apps,
                          title: 'Nenhum app encontrado',
                        );
                      }
                      return ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final a = shown[i];
                          return ListTile(
                            leading: a.icon == null
                                ? const Icon(Icons.android)
                                : Image.memory(
                                    a.icon!,
                                    width: 36,
                                    height: 36,
                                    gaplessPlayback: true,
                                  ),
                            title: Text(a.label),
                            subtitle: Text(
                              a.packageName,
                              style: const TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, a),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
